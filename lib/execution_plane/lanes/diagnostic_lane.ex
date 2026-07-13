defmodule ExecutionPlane.Lanes.DiagnosticLane do
  @moduledoc """
  Bounded, non-coding diagnostic lane adapter.

  The lane performs local diagnostic operations directly in the adapter. It
  does not spawn shell commands, materialize credentials, or mutate workspace
  contents.
  """

  @behaviour ExecutionPlane.Lane.Adapter

  alias ExecutionPlane.Admission.Rejection
  alias ExecutionPlane.Contracts
  alias ExecutionPlane.DiagnosticResult
  alias ExecutionPlane.ExecutionRequest
  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.Lane.Capabilities

  @target_class "local-erlexec-weak"
  @default_timeout_ms 30_000
  @default_max_output_bytes 65_536
  @default_probe_timeout_ms 250
  @allowed_probe_hosts ["127.0.0.1", "localhost", "::1"]

  @impl true
  def lane_id, do: :diagnostic

  @impl true
  def capabilities do
    Capabilities.new!(
      lane_id: "diagnostic",
      protocols: ["diagnostic"],
      surfaces: ["diagnostic", @target_class],
      supports_execute: true,
      supports_stream: false,
      metadata: %{
        "attestation" => "weak_local",
        "egress" => "localhost_only",
        "workspace_mutability" => "read_only"
      }
    )
  end

  @impl true
  def validate(%ExecutionRequest{lane_id: "diagnostic"}), do: :ok

  def validate(%ExecutionRequest{} = request) do
    {:error,
     Rejection.new(
       :invalid_lane_request,
       "diagnostic adapter only accepts lane_id=diagnostic",
       %{lane_id: request.lane_id}
     )}
  end

  @impl true
  def execute(%ExecutionRequest{} = request, opts) do
    case validate(request) do
      :ok ->
        run_request(request, opts)

      {:error, %Rejection{} = rejection} ->
        {:error, adapter_result(request, rejection_result(request, rejection))}
    end
  end

  @impl true
  def stream(%ExecutionRequest{} = request, _opts) do
    {:error,
     Rejection.new(
       :stream_not_supported,
       "diagnostic adapter does not expose stream/2 for execution requests",
       %{lane_id: request.lane_id}
     )}
  end

  defp run_request(%ExecutionRequest{} = request, opts) do
    started_at = now_ms()
    maybe_delay(request.payload)

    diagnostic =
      request
      |> operation_result(opts)
      |> DiagnosticResult.with_elapsed(elapsed_ms(started_at))
      |> enforce_timeout(timeout_ms(opts))
      |> enforce_output_size(max_output_bytes(opts))

    reply = adapter_result(request, diagnostic)

    if diagnostic.status == :ok do
      {:ok, reply}
    else
      {:error, reply}
    end
  end

  defp operation_result(%ExecutionRequest{operation: "diagnostic.echo", payload: payload}, _opts) do
    payload = Contracts.ensure_map!(payload, "diagnostic echo payload")
    message = payload |> Contracts.fetch_value(:message) |> echo_message()
    result("diagnostic.echo", :ok, %{"message" => message})
  end

  defp operation_result(%ExecutionRequest{operation: "diagnostic.system_info"}, _opts) do
    result("diagnostic.system_info", :ok, %{
      "otp_release" => System.otp_release(),
      "elixir_version" => System.version(),
      "scheduler_count" => System.schedulers_online()
    })
  end

  defp operation_result(
         %ExecutionRequest{operation: "diagnostic.workspace_stat", payload: payload},
         _opts
       ) do
    payload = Contracts.ensure_map!(payload, "diagnostic workspace stat payload")

    with path when is_binary(path) and path != "" <- Contracts.fetch_value(payload, :path),
         {:ok, stat} <- File.stat(path) do
      result("diagnostic.workspace_stat", :ok, %{
        "path" => path,
        "type" => Atom.to_string(stat.type),
        "size" => stat.size,
        "access" => Atom.to_string(stat.access)
      })
    else
      nil ->
        error_result("diagnostic.workspace_stat", "path_required")

      "" ->
        error_result("diagnostic.workspace_stat", "path_required")

      {:error, reason} ->
        error_result("diagnostic.workspace_stat", "stat_failed", %{
          "file_error" => inspect(reason)
        })
    end
  end

  defp operation_result(
         %ExecutionRequest{operation: "diagnostic.http_probe", payload: payload},
         opts
       ) do
    payload = Contracts.ensure_map!(payload, "diagnostic http probe payload")

    case build_probe(payload) do
      {:ok, probe} ->
        probe_timeout = Keyword.get(opts, :probe_timeout_ms, @default_probe_timeout_ms)
        probe_result("diagnostic.http_probe", probe, probe_timeout)

      {:error, reason} ->
        error_result("diagnostic.http_probe", reason)
    end
  end

  defp operation_result(%ExecutionRequest{operation: operation}, _opts)
       when is_binary(operation) do
    error_result(operation, "unsupported_operation")
  end

  defp operation_result(%ExecutionRequest{}, _opts) do
    error_result("diagnostic.unknown", "unsupported_operation")
  end

  defp build_probe(payload) do
    with url when is_binary(url) and url != "" <- Contracts.fetch_value(payload, :url),
         %URI{host: host, scheme: scheme} = uri when is_binary(host) and is_binary(scheme) <-
           URI.parse(url),
         true <- host in @allowed_probe_hosts,
         {:ok, port} <- probe_port(uri) do
      {:ok, %{host: host, port: port, scheme: scheme, url: url}}
    else
      false -> {:error, "probe_target_not_allowed"}
      nil -> {:error, "probe_url_required"}
      "" -> {:error, "probe_url_required"}
      {:error, reason} -> {:error, reason}
      _other -> {:error, "invalid_probe_url"}
    end
  end

  defp probe_port(%URI{port: port}) when is_integer(port) and port > 0, do: {:ok, port}
  defp probe_port(%URI{scheme: "http"}), do: {:ok, 80}
  defp probe_port(%URI{scheme: "https"}), do: {:ok, 443}
  defp probe_port(_uri), do: {:error, "unsupported_probe_scheme"}

  defp probe_result(operation, probe, timeout_ms) do
    socket_opts = [:binary, active: false]

    case :gen_tcp.connect(String.to_charlist(probe.host), probe.port, socket_opts, timeout_ms) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        result(operation, :ok, probe_payload(probe, true, nil))

      {:error, reason} ->
        result(operation, :ok, probe_payload(probe, false, Atom.to_string(reason)))
    end
  end

  defp probe_payload(probe, reachable?, error) do
    %{
      "url" => probe.url,
      "scheme" => probe.scheme,
      "host" => probe.host,
      "port" => probe.port,
      "reachable" => reachable?
    }
    |> maybe_put("error", error)
  end

  defp enforce_timeout(%DiagnosticResult{} = result, timeout_ms)
       when result.execution_time_ms > timeout_ms do
    DiagnosticResult.replace(result, :timeout, %{
      "reason" => "timeout_exceeded",
      "timeout_ms" => timeout_ms,
      "execution_time_ms" => result.execution_time_ms
    })
  end

  defp enforce_timeout(%DiagnosticResult{} = result, _timeout_ms), do: result

  defp enforce_output_size(%DiagnosticResult{status: :ok} = result, max_output_bytes) do
    encoded_size =
      result
      |> DiagnosticResult.dump()
      |> ExecutionPlane.Codec.encode!()
      |> byte_size()

    if encoded_size > max_output_bytes do
      DiagnosticResult.replace(result, :error, %{
        "reason" => "output_size_exceeded",
        "max_output_bytes" => max_output_bytes,
        "actual_output_bytes" => encoded_size
      })
    else
      result
    end
  end

  defp enforce_output_size(%DiagnosticResult{} = result, _max_output_bytes), do: result

  defp adapter_result(%ExecutionRequest{} = request, %DiagnosticResult{} = diagnostic) do
    ExecutionResult.new!(
      execution_ref: request.execution_ref,
      status: execution_status(diagnostic.status),
      output: %{"diagnostic_result" => DiagnosticResult.dump(diagnostic)},
      error: execution_error(diagnostic.status),
      provenance: request.provenance
    )
  end

  defp execution_status(:ok), do: "succeeded"
  defp execution_status(:error), do: "failed"
  defp execution_status(:timeout), do: "timeout"

  defp execution_error(:ok), do: nil
  defp execution_error(:error), do: "diagnostic execution failed"
  defp execution_error(:timeout), do: "diagnostic timeout"

  defp result(operation, status, payload) do
    DiagnosticResult.new!(
      operation: operation,
      status: status,
      payload: payload,
      execution_time_ms: 0,
      target_class: @target_class,
      attestation: :weak_local
    )
  end

  defp error_result(operation, reason, extra_payload \\ %{}) do
    payload = Map.put(extra_payload, "reason", reason)
    result(operation, :error, payload)
  end

  defp rejection_result(%ExecutionRequest{} = request, %Rejection{} = rejection) do
    error_result(request.operation || "diagnostic.unknown", "invalid_lane_request", %{
      "rejection" => Rejection.dump(rejection)
    })
  end

  defp echo_message(nil), do: ""
  defp echo_message(message) when is_binary(message), do: message
  defp echo_message(message), do: inspect(message)

  defp timeout_ms(opts), do: positive_integer_option(opts, :timeout_ms, @default_timeout_ms)

  defp max_output_bytes(opts),
    do: positive_integer_option(opts, :max_output_bytes, @default_max_output_bytes)

  defp positive_integer_option(opts, key, default) do
    case Keyword.get(opts, key, default) do
      value when is_integer(value) and value > 0 -> value
      _other -> default
    end
  end

  defp maybe_delay(payload) when is_map(payload) do
    case Contracts.fetch_value(payload, :delay_ms) do
      delay_ms when is_integer(delay_ms) and delay_ms > 0 -> Process.sleep(delay_ms)
      _other -> :ok
    end
  end

  defp maybe_delay(_payload), do: :ok

  defp now_ms, do: System.monotonic_time(:millisecond)
  defp elapsed_ms(started_at), do: max(now_ms() - started_at, 0)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
