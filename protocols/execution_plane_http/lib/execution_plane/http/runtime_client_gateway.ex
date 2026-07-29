defmodule ExecutionPlane.HTTP.RuntimeClientGateway do
  @moduledoc """
  HTTP-family adapter for an injected `ExecutionPlane.Runtime.Client`.

  Incremental responses use explicit demand encoded as Runtime Client input.
  Unary responses subscribe and request exactly one result. Runtime Client
  implementations deliver `ExecutionPlane.Runtime.Event` values directly or
  as `{:execution_plane_runtime, execution_ref, event}`. Output may carry the
  `ExecutionPlane.ExecutionResult` under `execution_result`, but unary return
  waits for the terminal receipt event and its non-empty `receipt_ref`.

  This adapter never selects a local implementation or silently falls back
  around governed admission.
  """

  @behaviour ExecutionPlane.Family.HTTPGateway

  alias ExecutionPlane.ActiveExecution
  alias ExecutionPlane.Admission.Request
  alias ExecutionPlane.ExecutionRef
  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.Family.HTTPRequest
  alias ExecutionPlane.Provenance
  alias ExecutionPlane.Runtime.Event

  @family_contract "execution-plane.runtime-families.v1"
  @max_demand 1_024
  @runtime_callbacks [
    start: 2,
    subscribe: 3,
    send_input: 3,
    end_input: 2,
    status: 2,
    cancel: 2
  ]

  @impl true
  def unary(%HTTPRequest{response_mode: "unary"} = request, opts) when is_list(opts) do
    with {:ok, timeout} <- receive_timeout(request, opts),
         {:ok, client, client_opts} <- runtime_client(opts),
         {:ok, active} <- start(request, "http.unary", client, client_opts, opts),
         :ok <- subscribe_or_cancel(active, self(), client, client_opts),
         :ok <- demand_or_cancel(active, 1, client, client_opts) do
      await_unary_result(active.execution_ref, client, client_opts, timeout)
    end
  end

  def unary(%HTTPRequest{}, _opts), do: {:error, :http_response_mode_mismatch}
  def unary(_request, _opts), do: {:error, :invalid_http_family_request}

  @doc """
  Encodes the frozen HTTP-family request as a transport-safe payload.
  """
  @spec encode_request(HTTPRequest.t()) :: map()
  def encode_request(%HTTPRequest{} = request) do
    %{
      "request_ref" => request.request_ref,
      "endpoint_ref" => request.endpoint_ref,
      "method" => request.method,
      "path" => request.path,
      "header_policy_ref" => request.header_policy_ref,
      "response_mode" => request.response_mode,
      "idempotency_key" => request.idempotency_key,
      "deadline_at" => DateTime.to_iso8601(request.deadline_at),
      "body_artifact_ref" => request.body_artifact_ref
    }
  end

  @doc """
  Loads a transport-safe HTTP-family payload at the effect boundary.
  """
  @spec decode_request(map()) :: {:ok, HTTPRequest.t()} | {:error, term()}
  def decode_request(attrs) when is_map(attrs) do
    with {:ok, deadline} <- parse_deadline(value(attrs, :deadline_at)) do
      HTTPRequest.new(%{
        request_ref: value(attrs, :request_ref),
        endpoint_ref: value(attrs, :endpoint_ref),
        method: value(attrs, :method),
        path: value(attrs, :path),
        header_policy_ref: value(attrs, :header_policy_ref),
        response_mode: value(attrs, :response_mode),
        idempotency_key: value(attrs, :idempotency_key),
        deadline_at: deadline,
        body_artifact_ref: value(attrs, :body_artifact_ref)
      })
    end
  end

  def decode_request(_attrs), do: {:error, :invalid_http_family_request}

  @impl true
  def stream(%HTTPRequest{response_mode: "incremental"} = request, subscriber, opts)
      when is_pid(subscriber) and is_list(opts) do
    with {:ok, _timeout} <- receive_timeout(request, opts),
         {:ok, client, client_opts} <- runtime_client(opts),
         {:ok, active} <- start(request, "http.stream", client, client_opts, opts),
         :ok <- subscribe_or_cancel(active, subscriber, client, client_opts) do
      {:ok, active}
    end
  end

  def stream(%HTTPRequest{}, _subscriber, _opts), do: {:error, :http_response_mode_mismatch}
  def stream(_request, _subscriber, _opts), do: {:error, :invalid_http_family_request}

  @impl true
  def demand(execution_ref, count, opts)
      when is_integer(count) and count > 0 and count <= @max_demand and is_list(opts) do
    with {:ok, ref} <- execution_ref(execution_ref),
         {:ok, client, client_opts} <- runtime_client(opts) do
      client.send_input(
        ref,
        %{"control" => "demand", "count" => count},
        client_opts
      )
    end
  end

  def demand(_execution_ref, _count, _opts), do: {:error, :invalid_http_demand}

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

  defp start(%HTTPRequest{} = request, operation, client, client_opts, opts) do
    with {:ok, admission} <- admission_request(request, operation, opts),
         {:ok, %ActiveExecution{} = active} <- client.start(admission, client_opts) do
      validate_active_execution(active, client, client_opts)
    end
  end

  defp admission_request(%HTTPRequest{} = request, operation, opts) do
    with {:ok, attrs} <- admission_attrs(opts),
         {:ok, metadata} <- admission_metadata(attrs) do
      attrs
      |> Map.put(:lane_id, "http")
      |> Map.put(:operation, operation)
      |> Map.put(:payload, family_payload(request))
      |> Map.put(:metadata, metadata)
      |> Map.put(
        :provenance,
        admission_value(attrs, :provenance) ||
          Provenance.node_admitted(%{
            owner: "execution_plane_http",
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

  defp family_payload(%HTTPRequest{} = request) do
    %{
      "family" => "http",
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

  defp subscribe_or_cancel(%ActiveExecution{} = active, subscriber, client, client_opts) do
    case client.subscribe(active.execution_ref, subscriber, client_opts) do
      :ok ->
        :ok

      {:error, _reason} = error ->
        _ =
          client.cancel(
            active.execution_ref,
            Keyword.put(client_opts, :reason, "subscription_failed")
          )

        error
    end
  end

  defp demand_or_cancel(%ActiveExecution{} = active, count, client, client_opts) do
    case client.send_input(
           active.execution_ref,
           %{"control" => "demand", "count" => count},
           client_opts
         ) do
      :ok ->
        :ok

      {:error, _reason} = error ->
        _ =
          client.cancel(
            active.execution_ref,
            Keyword.put(client_opts, :reason, "demand_failed")
          )

        error
    end
  end

  defp await_unary_result(
         %ExecutionRef{ref: ref} = execution_ref,
         client,
         client_opts,
         timeout
       ) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_await_unary_result(ref, execution_ref, client, client_opts, deadline, nil)
  end

  defp do_await_unary_result(
         ref,
         execution_ref,
         client,
         client_opts,
         deadline,
         pending_result
       ) do
    timeout = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      %Event{execution_ref: %ExecutionRef{ref: ^ref}} = event ->
        handle_unary_event(
          event,
          ref,
          execution_ref,
          client,
          client_opts,
          deadline,
          pending_result
        )

      {:execution_plane_runtime, ^ref, %Event{execution_ref: %ExecutionRef{ref: ^ref}} = event} ->
        handle_unary_event(
          event,
          ref,
          execution_ref,
          client,
          client_opts,
          deadline,
          pending_result
        )

      {:execution_plane_runtime, %ExecutionRef{ref: ^ref},
       %Event{execution_ref: %ExecutionRef{ref: ^ref}} = event} ->
        handle_unary_event(
          event,
          ref,
          execution_ref,
          client,
          client_opts,
          deadline,
          pending_result
        )
    after
      timeout ->
        _ =
          client.cancel(
            execution_ref,
            Keyword.put(client_opts, :reason, "unary_result_timeout")
          )

        {:error, :runtime_result_timeout}
    end
  end

  defp handle_unary_event(
         %Event{kind: kind, payload: payload},
         ref,
         execution_ref,
         client,
         client_opts,
         deadline,
         pending_result
       )
       when kind in ["output", "receipt"] do
    case {kind, execution_result(payload), pending_result} do
      {"output", {:ok, result}, _pending_result} ->
        do_await_unary_result(
          ref,
          execution_ref,
          client,
          client_opts,
          deadline,
          result
        )

      {"output", :none, pending_result} ->
        do_await_unary_result(
          ref,
          execution_ref,
          client,
          client_opts,
          deadline,
          pending_result
        )

      {"receipt", {:ok, result}, _pending_result} ->
        validate_receipt(payload, result)

      {"receipt", :none, %ExecutionResult{} = result} ->
        validate_receipt(payload, result)

      {"receipt", :none, nil} ->
        {:error, :runtime_receipt_without_result}

      {_kind, {:error, _reason} = error, _pending_result} ->
        error
    end
  end

  defp handle_unary_event(
         %Event{kind: "error", payload: payload},
         _ref,
         _execution_ref,
         _client,
         _client_opts,
         _deadline,
         _pending_result
       ),
       do: {:error, {:runtime_error, payload}}

  defp handle_unary_event(
         _event,
         ref,
         execution_ref,
         client,
         client_opts,
         deadline,
         pending_result
       ),
       do:
         do_await_unary_result(
           ref,
           execution_ref,
           client,
           client_opts,
           deadline,
           pending_result
         )

  defp validate_receipt(payload, result),
    do: if(receipt?(payload), do: {:ok, result}, else: {:error, :invalid_runtime_receipt})

  defp receipt?(payload) when is_map(payload) do
    case Map.get(payload, :receipt_ref, Map.get(payload, "receipt_ref")) do
      receipt_ref when is_binary(receipt_ref) -> String.trim(receipt_ref) != ""
      _other -> false
    end
  end

  defp receipt?(_payload), do: false

  defp execution_result(payload) when is_map(payload) do
    case Map.get(payload, :execution_result, Map.get(payload, "execution_result")) do
      nil -> :none
      %ExecutionResult{} = result -> {:ok, result}
      attrs when is_map(attrs) -> ExecutionResult.new(attrs)
      _other -> {:error, :invalid_runtime_execution_result}
    end
  end

  defp execution_result(_payload), do: {:error, :invalid_runtime_execution_result}

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

  defp validate_active_execution(%ActiveExecution{lane_id: "http"} = active, _client, _opts),
    do: {:ok, active}

  defp validate_active_execution(%ActiveExecution{} = active, client, opts) do
    _ = client.cancel(active.execution_ref, Keyword.put(opts, :reason, "runtime_lane_mismatch"))
    {:error, :runtime_lane_mismatch}
  end

  defp receive_timeout(%HTTPRequest{deadline_at: %DateTime{} = deadline}, opts) do
    remaining = DateTime.diff(deadline, DateTime.utc_now(), :millisecond)

    requested =
      case Keyword.get(opts, :receive_timeout, remaining) do
        timeout when is_integer(timeout) and timeout >= 0 -> timeout
        _other -> -1
      end

    if remaining > 0 and requested >= 0 do
      {:ok, min(remaining, requested)}
    else
      {:error, :deadline_expired}
    end
  end

  defp receive_timeout(_request, _opts), do: {:error, :invalid_http_family_request}

  defp parse_deadline(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, deadline, _offset} -> {:ok, deadline}
      {:error, _reason} -> {:error, :invalid_http_family_request}
    end
  end

  defp parse_deadline(_value), do: {:error, :invalid_http_family_request}

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
