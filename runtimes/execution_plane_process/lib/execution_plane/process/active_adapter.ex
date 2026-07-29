defmodule ExecutionPlane.Process.ActiveAdapter do
  @moduledoc false

  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.Process.RuntimeClientGateway
  alias ExecutionPlane.Process.Transport
  alias ExecutionPlane.ProcessExit

  @event_tag :execution_plane_process_active

  def start(request, owner, opts) do
    with {:ok, family_request} <- decode_family_request(request.payload),
         {:ok, cwd} <-
           materialize(
             Keyword.get(opts, :working_directories, %{}),
             family_request.working_directory_ref,
             :working_directory
           ),
         {:ok, env} <-
           materialize(
             Keyword.get(opts, :environment_materializations, %{}),
             family_request.environment_materialization_ref,
             :environment
           ),
         true <- is_nil(cwd) or is_binary(cwd),
         true <- is_map(env) do
      token = make_ref()

      transport_opts = [
        command: family_request.executable,
        args: family_request.arguments,
        cwd: cwd,
        env: env,
        clear_env?: Keyword.get(opts, :clear_env?, true),
        pty?: family_request.stdin_mode == "pty",
        subscriber: {owner, token},
        event_tag: @event_tag,
        buffer_events_until_subscribe?: true,
        headless_timeout_ms: deadline_timeout(family_request.deadline_at)
      ]

      case Transport.start(transport_opts) do
        {:ok, transport} ->
          {:ok,
           %{
             transport: transport,
             monitor_pid: transport,
             token: token,
             request: request,
             input?: family_request.stdin_mode != "none"
           }}

        {:error, reason} ->
          {:error, reason}
      end
    else
      false -> {:error, :invalid_process_materialization}
      {:error, _reason} = error -> error
    end
  end

  def send_input(%{input?: true, transport: transport}, input),
    do: Transport.send(transport, input)

  def send_input(%{input?: false}, _input), do: {:error, :process_input_not_supported}

  def end_input(%{input?: true, transport: transport}), do: Transport.end_input(transport)
  def end_input(%{input?: false}), do: {:error, :process_input_not_supported}

  def cancel(%{transport: transport}, _reason) do
    _ = Transport.interrupt(transport)
    Transport.force_close(transport)
  end

  def event(
        %{token: token},
        {@event_tag, token, {:message, data}}
      ),
      do: {:ok, {:output, %{"family" => "process", "stream" => "stdout", "data" => data}}}

  def event(
        %{token: token},
        {@event_tag, token, {:data, data}}
      ),
      do: {:ok, {:output, %{"family" => "process", "stream" => "stdout", "data" => data}}}

  def event(
        %{token: token},
        {@event_tag, token, {:stderr, data}}
      ),
      do: {:ok, {:output, %{"family" => "process", "stream" => "stderr", "data" => data}}}

  def event(%{token: token}, {@event_tag, token, {:error, error}}),
    do: {:ok, {:status, %{"family" => "process", "transport_error" => inspect(error.reason)}}}

  def event(
        %{token: token, request: request},
        {@event_tag, token, {:exit, %ProcessExit{} = process_exit}}
      ) do
    status = if ProcessExit.successful?(process_exit), do: "succeeded", else: "failed"
    terminal_state = if status == "succeeded", do: "completed", else: "failed"

    result =
      ExecutionResult.new!(
        execution_ref: request.execution_ref,
        status: status,
        output: %{
          "process_exit" => %{
            "status" => to_string(process_exit.status),
            "code" => process_exit.code,
            "signal" => normalize_signal(process_exit.signal)
          }
        },
        error: if(status == "failed", do: %{"reason" => inspect(process_exit.reason)}, else: nil),
        provenance: request.provenance
      )

    {:ok, {:terminal, terminal_state, result}}
  end

  def event(_handle, _message), do: :ignore

  defp decode_family_request(%{"family" => "process", "request" => request}),
    do: RuntimeClientGateway.decode_request(request)

  defp decode_family_request(%{family: "process", request: request}),
    do: RuntimeClientGateway.decode_request(request)

  defp decode_family_request(_payload), do: {:error, :invalid_process_family_payload}

  defp materialize(materializations, ref, kind) when is_map(materializations) do
    case Map.fetch(materializations, ref) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:unknown_process_materialization, kind, ref}}
    end
  end

  defp materialize(_materializations, ref, kind),
    do: {:error, {:invalid_process_materializations, kind, ref}}

  defp deadline_timeout(deadline) do
    max(DateTime.diff(deadline, DateTime.utc_now(), :millisecond), 1)
  end

  defp normalize_signal(nil), do: nil
  defp normalize_signal(signal), do: to_string(signal)
end
