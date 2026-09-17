defmodule ExecutionPlane.HTTP do
  @moduledoc """
  Helper surface for unary HTTP request/response execution.

  Callers provide semantic request data plus optional lineage or envelope
  overrides. This helper emits `HttpExecutionIntent.v1`, resolves the matching
  minimal route, and executes the request through the kernel.

  `start_unary/2`, `await_unary/2`, and `cancel_unary/2` provide a lightweight
  cancelable lifecycle over the same kernel and protocol path. Cancellation is
  delegated to the request-owning process so the real `:httpc` request is
  cancelled rather than merely abandoning the caller's wait.
  """

  alias ExecutionPlane.Admission.Rejection
  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.HttpExecutionIntent.V1, as: HttpExecutionIntent
  alias ExecutionPlane.ExecutionRequest
  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.HTTP.{ActiveAdapter, UnarySession}
  alias ExecutionPlane.Kernel
  alias ExecutionPlane.Kernel.ExecutionResult, as: KernelExecutionResult
  alias ExecutionPlane.Lane.Capabilities
  alias ExecutionPlane.LaneSupport

  @behaviour ExecutionPlane.Lane.Adapter

  @impl true
  def lane_id, do: :http

  @impl true
  def capabilities do
    Capabilities.new!(
      lane_id: "http",
      protocols: ["http"],
      surfaces: ["http", "https"],
      supports_execute: true,
      supports_stream: true,
      metadata: %{"active_runtime_client" => true}
    )
  end

  @impl true
  def validate(%ExecutionRequest{lane_id: "http"}), do: :ok

  def validate(_request) do
    {:error,
     Rejection.new(
       :invalid_lane_request,
       "HTTP adapter only accepts lane_id=http"
     )}
  end

  @impl true
  def execute(%ExecutionRequest{} = request, opts) do
    request.payload
    |> unary(opts)
    |> case do
      {:ok, result} ->
        {:ok, adapter_result(request, "succeeded", result, nil)}

      {:error, result} ->
        {:error, adapter_result(request, "failed", result, "http execution failed")}
    end
  end

  @impl true
  def stream(%ExecutionRequest{} = request, _opts) do
    {:error,
     Rejection.new(
       :stream_not_supported,
       "HTTP unary adapter does not expose stream/2 for execution requests",
       %{lane_id: request.lane_id}
     )}
  end

  @doc false
  def active_start(%ExecutionRequest{} = request, owner, opts) when is_pid(owner),
    do: ActiveAdapter.start(request, owner, opts)

  @doc false
  def active_send_input(session, input, _opts),
    do: ActiveAdapter.send_input(session, input)

  @doc false
  def active_end_input(session, _opts),
    do: ActiveAdapter.end_input(session)

  @doc false
  def active_cancel(session, reason, _opts),
    do: ActiveAdapter.cancel(session, reason)

  @doc false
  def active_event(session, message, _opts),
    do: ActiveAdapter.event(session, message)

  @doc """
  Starts a cancelable unary HTTP execution.

  For real HTTP requests this returns after `:httpc` has assigned the active
  request identifier. Lower-simulation executions may complete before an HTTP
  request is created; successful simulated results are retained in the returned
  session and are immediately available from `await_unary/2`.

  The process that calls `start_unary/2` is the result owner. Cancellation may
  be requested from another BEAM process, but `await_unary/2` must be called by
  the owner so terminal mailbox delivery remains deterministic.
  """
  @spec start_unary(map() | keyword(), keyword()) ::
          {:ok, UnarySession.t()} | {:error, KernelExecutionResult.t() | term()}
  def start_unary(request, opts \\ []) do
    UnarySession.start(fn owner, session_ref ->
      execute_unary(request, opts, {owner, session_ref})
    end)
  end

  @doc """
  Awaits a cancelable unary session's terminal kernel result.

  If `timeout` expires, the underlying request is cancelled before
  `{:error, :timeout}` is returned.
  """
  @spec await_unary(UnarySession.t(), timeout()) ::
          {:ok, KernelExecutionResult.t()} | {:error, KernelExecutionResult.t() | term()}
  defdelegate await_unary(session, timeout \\ :infinity), to: UnarySession, as: :await

  @doc """
  Cancels an active unary session.

  The request-owning worker acknowledges cancellation only after the lower
  `ExecutionPlane.Protocols.HTTP.cancel_request/1` call has run. Repeated
  cancellation and cancellation after normal completion are harmless. A normal
  response that already won the asynchronous completion/cancellation race may
  still be the terminal result. The cancellation reason is lifecycle metadata
  and is not copied into the execution outcome.
  """
  @spec cancel_unary(UnarySession.t(), term()) :: :ok | {:error, term()}
  defdelegate cancel_unary(session, reason), to: UnarySession, as: :cancel

  @spec unary(map() | keyword(), keyword()) ::
          {:ok, KernelExecutionResult.t()} | {:error, KernelExecutionResult.t()}
  def unary(request, opts \\ []) do
    execute_unary(request, opts, nil)
  end

  defp execute_unary(request, opts, unary_session) do
    request = Contracts.normalize_attrs(request)
    url = Contracts.fetch_required_stringish!(request, :url)
    timeout_ms = timeout_ms(request)
    lineage = LaneSupport.build_lineage("http", Keyword.get(opts, :lineage, %{}))

    intent =
      HttpExecutionIntent.new!(%{
        envelope:
          LaneSupport.build_envelope(
            "http",
            "http",
            "http.unary",
            lineage,
            Keyword.get(opts, :envelope, %{})
          ),
        request_shape:
          Contracts.fetch_optional_stringish!(request, :request_shape, "request_response"),
        stream_mode: Contracts.fetch_optional_stringish!(request, :stream_mode, "unary"),
        headers: normalize_headers(Contracts.fetch_value(request, :headers) || %{}),
        body: Contracts.fetch_value(request, :body),
        egress_surface:
          request
          |> execution_surface(url)
          |> Contracts.ensure_map!("egress_surface"),
        timeouts: request_timeouts(request, timeout_ms),
        retry_class: Contracts.fetch_optional_stringish!(request, :retry_class)
      })

    route =
      LaneSupport.build_route(
        "http",
        "http",
        "http",
        "local",
        %{
          "url" => url,
          "method" => Contracts.fetch_optional_stringish!(request, :method, "POST")
        },
        timeout_ms,
        lineage,
        Keyword.get(opts, :route, %{})
      )

    kernel_opts =
      opts
      |> LaneSupport.kernel_opts()
      |> maybe_put_unary_session(unary_session)

    Kernel.execute(intent, route, kernel_opts)
  end

  defp maybe_put_unary_session(opts, {owner, session_ref})
       when is_pid(owner) and is_reference(session_ref) do
    Keyword.put(opts, :execution_plane_http_unary_session, {owner, session_ref})
  end

  defp maybe_put_unary_session(opts, _session), do: opts

  defp normalize_headers(headers) when is_map(headers) do
    Map.new(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    Map.new(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_headers(_headers), do: %{}

  defp request_timeouts(request, timeout_ms) do
    request
    |> Contracts.fetch_optional_map!(:timeouts, %{})
    |> maybe_put_timeout(timeout_ms)
  end

  defp timeout_ms(request) do
    case Contracts.fetch_value(request, :timeout_ms) do
      timeout when is_integer(timeout) and timeout > 0 -> timeout
      _other -> nil
    end
  end

  defp execution_surface(request, url) do
    case Contracts.fetch_value(request, :egress_surface) do
      nil -> %{"surface_kind" => uri_surface_kind(url)}
      surface -> surface
    end
  end

  defp uri_surface_kind(url) do
    case URI.parse(url).scheme do
      "http" -> "http"
      "https" -> "https"
      _other -> "https"
    end
  end

  defp maybe_put_timeout(timeouts, timeout_ms) when is_integer(timeout_ms) and timeout_ms > 0 do
    Map.put(timeouts, "request_timeout_ms", timeout_ms)
  end

  defp maybe_put_timeout(timeouts, _timeout_ms), do: timeouts

  defp adapter_result(%ExecutionRequest{} = request, status, result, error) do
    ExecutionResult.new!(
      execution_ref: request.execution_ref,
      status: status,
      output: %{
        "events" => Enum.map(result.events, &ExecutionPlane.Boundary.dump_value/1),
        "outcome" => ExecutionPlane.Boundary.dump_value(result.outcome)
      },
      error: error,
      provenance: request.provenance
    )
  end
end
