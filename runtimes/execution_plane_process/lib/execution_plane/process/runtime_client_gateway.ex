defmodule ExecutionPlane.Process.RuntimeClientGateway do
  @moduledoc """
  Process-family adapter for an injected `ExecutionPlane.Runtime.Client`.

  This module performs no client selection and starts no local fallback. A
  managed composition must inject the exact Runtime Client and its admission
  envelope for every operation.
  """

  @behaviour ExecutionPlane.Family.ProcessGateway

  alias ExecutionPlane.ActiveExecution
  alias ExecutionPlane.Admission.Request
  alias ExecutionPlane.ExecutionRef
  alias ExecutionPlane.Family.ProcessRequest
  alias ExecutionPlane.Provenance

  @family_contract "execution-plane.runtime-families.v1"
  @runtime_callbacks [
    start: 2,
    subscribe: 3,
    send_input: 3,
    end_input: 2,
    status: 2,
    cancel: 2
  ]

  @impl true
  def start(%ProcessRequest{} = request, opts) when is_list(opts) do
    with :ok <- validate_deadline(request.deadline_at),
         {:ok, client, client_opts} <- runtime_client(opts),
         {:ok, admission} <- admission_request(request, opts),
         {:ok, %ActiveExecution{} = active} <- client.start(admission, client_opts) do
      validate_active_execution(active, client, client_opts)
    end
  end

  def start(_request, _opts), do: {:error, :invalid_process_family_request}

  @doc """
  Encodes the frozen process-family request as a transport-safe payload.
  """
  @spec encode_request(ProcessRequest.t()) :: map()
  def encode_request(%ProcessRequest{} = request) do
    %{
      "command_ref" => request.command_ref,
      "executable" => request.executable,
      "arguments" => request.arguments,
      "working_directory_ref" => request.working_directory_ref,
      "environment_materialization_ref" => request.environment_materialization_ref,
      "stdin_mode" => request.stdin_mode,
      "deadline_at" => DateTime.to_iso8601(request.deadline_at)
    }
  end

  @doc """
  Loads a transport-safe process-family payload at the effect boundary.
  """
  @spec decode_request(map()) :: {:ok, ProcessRequest.t()} | {:error, term()}
  def decode_request(attrs) when is_map(attrs) do
    with {:ok, deadline} <- parse_deadline(value(attrs, :deadline_at)) do
      ProcessRequest.new(%{
        command_ref: value(attrs, :command_ref),
        executable: value(attrs, :executable),
        arguments: value(attrs, :arguments),
        working_directory_ref: value(attrs, :working_directory_ref),
        environment_materialization_ref: value(attrs, :environment_materialization_ref),
        stdin_mode: value(attrs, :stdin_mode),
        deadline_at: deadline
      })
    end
  end

  def decode_request(_attrs), do: {:error, :invalid_process_family_request}

  @impl true
  def attach(execution_ref, subscriber, opts) when is_pid(subscriber) and is_list(opts) do
    with {:ok, ref} <- execution_ref(execution_ref),
         {:ok, client, client_opts} <- runtime_client(opts) do
      client.subscribe(ref, subscriber, client_opts)
    end
  end

  def attach(_execution_ref, _subscriber, _opts), do: {:error, :invalid_subscriber}

  @impl true
  def send_input(execution_ref, input, opts) when is_list(opts) do
    with {:ok, ref} <- execution_ref(execution_ref),
         {:ok, client, client_opts} <- runtime_client(opts) do
      client.send_input(ref, input, client_opts)
    end
  end

  @impl true
  def end_input(execution_ref, opts) when is_list(opts) do
    with {:ok, ref} <- execution_ref(execution_ref),
         {:ok, client, client_opts} <- runtime_client(opts) do
      client.end_input(ref, client_opts)
    end
  end

  @impl true
  def status(execution_ref, opts) when is_list(opts) do
    with {:ok, ref} <- execution_ref(execution_ref),
         {:ok, client, client_opts} <- runtime_client(opts) do
      client.status(ref, client_opts)
    end
  end

  @impl true
  def cancel(execution_ref, opts) when is_list(opts) do
    with {:ok, ref} <- execution_ref(execution_ref),
         {:ok, client, client_opts} <- runtime_client(opts) do
      client.cancel(ref, client_opts)
    end
  end

  @impl true
  def terminate(execution_ref, opts) when is_list(opts) do
    with {:ok, ref} <- execution_ref(execution_ref),
         {:ok, client, client_opts} <- runtime_client(opts) do
      client.cancel(ref, Keyword.put(client_opts, :reason, "terminated"))
    end
  end

  defp admission_request(%ProcessRequest{} = request, opts) do
    with {:ok, attrs} <- admission_attrs(opts),
         {:ok, metadata} <- admission_metadata(attrs) do
      attrs
      |> Map.put(:lane_id, "process")
      |> Map.put(:operation, "process.start")
      |> Map.put(:payload, family_payload(request))
      |> Map.put(:metadata, metadata)
      |> Map.put(
        :provenance,
        admission_value(attrs, :provenance) ||
          Provenance.node_admitted(%{
            owner: "execution_plane_process",
            details: %{"family_contract" => @family_contract}
          })
      )
      |> Request.new()
    end
  end

  defp admission_attrs(opts) do
    case Keyword.get(opts, :admission, %{}) do
      %Request{} = request ->
        {:ok, Map.from_struct(request)}

      attrs when is_map(attrs) ->
        {:ok, attrs}

      attrs when is_list(attrs) ->
        if Keyword.keyword?(attrs), do: {:ok, Map.new(attrs)}, else: error()

      _other ->
        error()
    end
  end

  defp admission_metadata(attrs) do
    case admission_value(attrs, :metadata) do
      nil ->
        {:ok, %{"family_contract" => @family_contract}}

      metadata when is_map(metadata) ->
        metadata
        |> Map.put("family_contract", @family_contract)
        |> validate_safe_metadata()

      _other ->
        {:error, :invalid_runtime_admission}
    end
  end

  defp family_payload(%ProcessRequest{} = request) do
    %{
      "family" => "process",
      "family_contract" => @family_contract,
      "request" => encode_request(request)
    }
  end

  defp validate_safe_metadata(metadata) do
    case ExecutionPlane.Codec.encode(metadata) do
      {:ok, _encoded} -> {:ok, metadata}
      {:error, reason} -> {:error, reason}
    end
  end

  defp runtime_client(opts) do
    with {:ok, client} <- Keyword.fetch(opts, :runtime_client),
         true <- is_atom(client) and runtime_client?(client),
         client_opts when is_list(client_opts) <- Keyword.get(opts, :runtime_client_opts, []),
         true <- Keyword.keyword?(client_opts) do
      {:ok, client, client_opts}
    else
      _other -> {:error, :invalid_runtime_client}
    end
  end

  defp runtime_client?(client) do
    Code.ensure_loaded?(client) and
      Enum.all?(@runtime_callbacks, fn {callback, arity} ->
        function_exported?(client, callback, arity)
      end)
  end

  defp validate_active_execution(%ActiveExecution{lane_id: "process"} = active, _client, _opts),
    do: {:ok, active}

  defp validate_active_execution(%ActiveExecution{} = active, client, opts) do
    _ = client.cancel(active.execution_ref, Keyword.put(opts, :reason, "runtime_lane_mismatch"))
    {:error, :runtime_lane_mismatch}
  end

  defp validate_deadline(%DateTime{} = deadline) do
    if DateTime.compare(deadline, DateTime.utc_now()) == :gt,
      do: :ok,
      else: {:error, :deadline_expired}
  end

  defp validate_deadline(_deadline), do: {:error, :invalid_process_family_request}

  defp parse_deadline(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, deadline, _offset} -> {:ok, deadline}
      {:error, _reason} -> {:error, :invalid_process_family_request}
    end
  end

  defp parse_deadline(_value), do: {:error, :invalid_process_family_request}

  defp execution_ref(%ExecutionRef{ref: ref} = execution_ref)
       when is_binary(ref) and ref != "",
       do: {:ok, execution_ref}

  defp execution_ref(ref) when is_binary(ref) and ref != "", do: ExecutionRef.new(ref: ref)

  defp execution_ref(%{} = attrs) do
    case ExecutionRef.new(attrs) do
      {:ok, %ExecutionRef{ref: ref} = execution_ref} when is_binary(ref) and ref != "" ->
        {:ok, execution_ref}

      _other ->
        {:error, :invalid_execution_ref}
    end
  end

  defp execution_ref(_execution_ref), do: {:error, :invalid_execution_ref}

  defp admission_value(attrs, key),
    do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))

  defp value(attrs, key), do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))

  defp error, do: {:error, :invalid_runtime_admission}
end
