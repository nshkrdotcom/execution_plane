defmodule ExecutionPlane.Protocols.HTTP do
  @moduledoc """
  Minimal unary HTTP execution for the lower substrate.

  The ordinary `execute/2` path remains synchronous from the caller's point of
  view. `start_request/6` and `cancel_request/1` expose the lower `:httpc`
  primitives needed by `ExecutionPlane.HTTP.start_unary/2` without introducing
  a second HTTP client or bypassing the kernel lifecycle.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.Failure
  alias ExecutionPlane.Kernel.DispatchPlan
  alias ExecutionPlane.LowerSimulation

  @http_method_aliases %{
    "delete" => :delete,
    "get" => :get,
    "head" => :head,
    "options" => :options,
    "patch" => :patch,
    "post" => :post,
    "put" => :put,
    "trace" => :trace
  }
  @http_methods Map.values(@http_method_aliases)

  @type request_id :: term()

  @spec protocol() :: String.t()
  def protocol, do: "http"

  @spec supported_stream_modes() :: [String.t(), ...]
  def supported_stream_modes, do: ["unary", "sse"]

  @spec supports_intent?(struct() | map() | keyword()) :: boolean()
  def supports_intent?(%{__struct__: ExecutionPlane.Contracts.HttpExecutionIntent.V1}), do: true
  def supports_intent?(_other), do: false

  @spec execute(DispatchPlan.t(), keyword()) :: {:ok, map()} | {:error, map()}
  def execute(
        %DispatchPlan{
          intent: %{__struct__: ExecutionPlane.Contracts.HttpExecutionIntent.V1} = intent,
          route: route,
          timeout_ms: timeout_ms
        },
        opts
      ) do
    url = Contracts.fetch_value(route.resolved_target, :url)
    headers = normalize_headers(intent.headers)
    body = normalize_body(intent.body)
    content_type = content_type(headers, body)
    start_ms = System.monotonic_time(:millisecond)

    case route.resolved_target |> Contracts.fetch_value(:method) |> normalize_method() do
      {:ok, method} ->
        case LowerSimulation.execute_if_configured("http", intent, route, start_ms) do
          :not_configured ->
            execute_http_request(
              method,
              url,
              headers,
              content_type,
              body,
              timeout_ms,
              start_ms,
              opts
            )

          {:ok, execution} ->
            {:ok, execution}

          {:error, execution} ->
            {:error, execution}
        end

      {:error, {:invalid_http_method, method}} ->
        invalid_method_result(method, start_ms)
    end
  end

  @doc """
  Starts a real asynchronous `:httpc` request owned by the calling process.

  The returned request identifier is the lower transport handle used by
  `cancel_request/1`. Completion is delivered to the caller as the standard
  `{:http, {request_id, response}}` message from `:httpc`.
  """
  @spec start_request(atom(), String.t(), list(), String.t(), iodata(), pos_integer()) ::
          {:ok, request_id()} | {:error, term()}
  def start_request(method, url, headers, content_type, body, timeout_ms)
      when is_atom(method) and is_binary(url) and is_list(headers) and
             is_binary(content_type) and is_integer(timeout_ms) and timeout_ms > 0 do
    ensure_http_started()
    request = build_httpc_request(method, url, headers, content_type, body)
    http_options = [timeout: timeout_ms, connect_timeout: timeout_ms]

    :httpc.request(method, request, http_options,
      sync: false,
      receiver: self(),
      body_format: :binary
    )
  end

  @doc """
  Cancels an active `:httpc` request.

  Cancellation is physical lower-transport cancellation; it delegates to
  `:httpc.cancel_request/1` rather than merely abandoning a waiter. As with the
  underlying OTP API, a response that completed concurrently may already be in
  the receiver mailbox, so the caller still owns terminal race resolution.
  """
  @spec cancel_request(request_id() | nil) :: :ok
  def cancel_request(nil), do: :ok
  def cancel_request(request_id), do: :httpc.cancel_request(request_id)

  defp execute_http_request(
         method,
         url,
         headers,
         content_type,
         body,
         timeout_ms,
         start_ms,
         opts
       ) do
    case Keyword.get(opts, :execution_plane_http_unary_session) do
      {owner, session_ref} when is_pid(owner) and is_reference(session_ref) ->
        execute_cancelable_http_request(
          method,
          url,
          headers,
          content_type,
          body,
          timeout_ms,
          start_ms,
          owner,
          session_ref
        )

      _other ->
        execute_sync_http_request(method, url, headers, content_type, body, timeout_ms, start_ms)
    end
  end

  defp execute_sync_http_request(method, url, headers, content_type, body, timeout_ms, start_ms) do
    ensure_http_started()

    case do_request(method, url, headers, content_type, body, timeout_ms) do
      {:ok, status_code, response_headers, response_body} ->
        success_result(status_code, response_headers, response_body, start_ms)

      {:error, reason} ->
        transport_failure_result(reason, start_ms)
    end
  end

  defp execute_cancelable_http_request(
         method,
         url,
         headers,
         content_type,
         body,
         timeout_ms,
         start_ms,
         owner,
         session_ref
       ) do
    case start_request(method, url, headers, content_type, body, timeout_ms) do
      {:ok, request_id} ->
        send(owner, {:execution_plane_http_unary_started, session_ref, request_id, self()})
        await_cancelable_request(request_id, start_ms, owner, session_ref)

      {:error, reason} ->
        transport_failure_result(reason, start_ms)
    end
  end

  defp await_cancelable_request(request_id, start_ms, owner, session_ref) do
    owner_monitor = Process.monitor(owner)

    receive do
      {:http, {^request_id, response}} ->
        Process.demonitor(owner_monitor, [:flush])
        normalize_async_response(response, start_ms)

      {:execution_plane_http_unary_cancel, ^session_ref, _reason, ack_to, ack_ref}
      when is_pid(ack_to) and is_reference(ack_ref) ->
        cancellation_result = cancel_request(request_id)
        send(ack_to, {:execution_plane_http_unary_cancel_ack, ack_ref, cancellation_result})
        Process.demonitor(owner_monitor, [:flush])

        cancellation_failure_result(start_ms)

      {:DOWN, ^owner_monitor, :process, ^owner, _reason} ->
        :ok = cancel_request(request_id)
        cancellation_failure_result(start_ms)
    end
  end

  defp normalize_async_response(
         {{_version, status_code, _reason_phrase}, response_headers, response_body},
         start_ms
       ) do
    success_result(
      status_code,
      normalize_response_headers(response_headers),
      IO.iodata_to_binary(response_body),
      start_ms
    )
  end

  defp normalize_async_response({:error, reason}, start_ms) do
    transport_failure_result(reason, start_ms)
  end

  defp success_result(status_code, response_headers, response_body, start_ms) do
    {:ok,
     %{
       family: "http",
       raw_payload: %{
         status_code: status_code,
         headers: response_headers,
         body: response_body
       },
       metrics: %{"duration_ms" => System.monotonic_time(:millisecond) - start_ms},
       failure: nil
     }}
  end

  defp transport_failure_result(reason, start_ms) do
    failure_result(
      :transport_failed,
      "http request failed",
      %{error: inspect(reason)},
      start_ms
    )
  end

  defp cancellation_failure_result(start_ms) do
    failure_result(
      :cancellation,
      "http request cancelled",
      %{error: "cancelled"},
      start_ms
    )
  end

  defp failure_result(failure_class, reason, raw_payload, start_ms, details \\ %{}) do
    {:error,
     %{
       family: "http",
       raw_payload: raw_payload,
       metrics: %{"duration_ms" => System.monotonic_time(:millisecond) - start_ms},
       failure:
         Failure.new!(%{
           failure_class: failure_class,
           reason: reason,
           details: details
         })
     }}
  end

  defp ensure_http_started do
    _ = Application.ensure_all_started(:inets)
    _ = Application.ensure_all_started(:ssl)
    :ok
  end

  defp normalize_method(nil), do: {:ok, :post}

  defp normalize_method(method) when is_atom(method) do
    if method in @http_methods do
      {:ok, method}
    else
      {:error, {:invalid_http_method, method}}
    end
  end

  defp normalize_method(method) when is_binary(method) do
    case Map.fetch(@http_method_aliases, String.downcase(method)) do
      {:ok, normalized_method} -> {:ok, normalized_method}
      :error -> {:error, {:invalid_http_method, method}}
    end
  end

  defp normalize_method(method), do: {:error, {:invalid_http_method, method}}

  defp normalize_headers(headers) when is_map(headers) do
    Enum.map(headers, fn {key, value} ->
      {String.to_charlist(to_string(key)), String.to_charlist(to_string(value))}
    end)
  end

  defp normalize_body(body) when body in [%{}, []], do: ""
  defp normalize_body(body) when is_binary(body), do: body
  defp normalize_body(body) when is_map(body) or is_list(body), do: Jason.encode!(body)
  defp normalize_body(body), do: to_string(body)

  defp content_type(headers, body) do
    Enum.find_value(headers, "application/json", fn
      {~c"content-type", value} -> to_string(value)
      _other -> nil
    end)
    |> case do
      "application/json" = content_type when body != "" -> content_type
      content_type when is_binary(content_type) -> content_type
      _other -> "text/plain"
    end
  end

  defp do_request(method, url, headers, content_type, body, timeout_ms) do
    request = build_httpc_request(method, url, headers, content_type, body)
    http_options = [timeout: timeout_ms, connect_timeout: timeout_ms]
    options = [body_format: :binary]

    case :httpc.request(method, request, http_options, options) do
      {:ok, {{_version, status_code, _reason_phrase}, response_headers, response_body}} ->
        {:ok, status_code, normalize_response_headers(response_headers),
         IO.iodata_to_binary(response_body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_httpc_request(method, url, headers, content_type, body) do
    if body == "" and method in [:get, :delete] do
      {String.to_charlist(url), headers}
    else
      {String.to_charlist(url), headers, String.to_charlist(content_type), body}
    end
  end

  defp normalize_response_headers(headers) do
    Enum.into(headers, %{}, fn {key, value} ->
      {to_string(key), to_string(value)}
    end)
  end

  defp invalid_method_result(method, start_ms) do
    failure_result(
      :transport_failed,
      "invalid http method",
      %{error: "invalid_http_method: #{inspect(method)}"},
      start_ms
    )
  end
end
