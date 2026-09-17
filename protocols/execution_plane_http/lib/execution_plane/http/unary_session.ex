defmodule ExecutionPlane.HTTP.UnarySession do
  @moduledoc """
  Opaque handle for one cancelable unary HTTP execution.

  Sessions are created by `ExecutionPlane.HTTP.start_unary/2`. The process that
  starts a session is its result owner and must call
  `ExecutionPlane.HTTP.await_unary/2`.
  Cancellation may be triggered from another BEAM process with
  `ExecutionPlane.HTTP.cancel_unary/2`.

  The request identifier is an implementation detail of the lower `:httpc`
  transport and must not be persisted or treated as a durable execution ref.
  """

  alias ExecutionPlane.Kernel.ExecutionResult, as: KernelExecutionResult

  @enforce_keys [:ref, :owner]
  defstruct [:request_id, :worker, :monitor, :ref, :owner, :completed_result]

  @opaque t :: %__MODULE__{
            request_id: term() | nil,
            worker: pid() | nil,
            monitor: reference() | nil,
            ref: reference(),
            owner: pid(),
            completed_result:
              {:ok, KernelExecutionResult.t()} | {:error, KernelExecutionResult.t()} | nil
          }

  @cancel_ack_timeout_ms 5_000

  @doc false
  @spec start((pid(), reference() ->
                 {:ok, KernelExecutionResult.t()} | {:error, KernelExecutionResult.t()})) ::
          {:ok, t()} | {:error, term()}
  def start(execute) do
    owner = self()
    session_ref = make_ref()

    {worker, monitor} =
      spawn_monitor(fn ->
        result = execute.(owner, session_ref)
        send(owner, {:execution_plane_http_unary_finished, session_ref, self(), result})
      end)

    await_session_start(%__MODULE__{
      ref: session_ref,
      owner: owner,
      worker: worker,
      monitor: monitor
    })
  end

  @doc false
  @spec await(t(), timeout()) :: {:ok, KernelExecutionResult.t()} | {:error, term()}
  def await(session, timeout \\ :infinity)

  def await(%__MODULE__{completed_result: result}, _timeout) when not is_nil(result),
    do: result

  def await(%__MODULE__{owner: owner}, _timeout) when owner != self(),
    do: {:error, :not_session_owner}

  def await(%__MODULE__{} = session, timeout) do
    receive do
      {:execution_plane_http_unary_finished, ref, worker, result}
      when ref == session.ref and worker == session.worker ->
        await_worker_exit(session)
        result

      {:DOWN, monitor, :process, worker, reason}
      when monitor == session.monitor and worker == session.worker ->
        {:error, {:unary_worker_exit, reason}}
    after
      timeout ->
        case cancel(session, :await_timeout) do
          :ok ->
            _ = await(session)
            {:error, :timeout}

          {:error, _} = error ->
            error
        end
    end
  end

  @doc false
  @spec cancel(t(), term()) :: :ok | {:error, term()}
  def cancel(%__MODULE__{completed_result: result}, _reason) when not is_nil(result),
    do: :ok

  def cancel(%__MODULE__{worker: nil}, _reason), do: :ok

  def cancel(%__MODULE__{worker: worker, ref: session_ref}, reason) when is_pid(worker) do
    if Process.alive?(worker) do
      ack_ref = make_ref()
      monitor = Process.monitor(worker)

      send(
        worker,
        {:execution_plane_http_unary_cancel, session_ref, reason, self(), ack_ref}
      )

      receive do
        {:execution_plane_http_unary_cancel_ack, ^ack_ref, :ok} ->
          Process.demonitor(monitor, [:flush])
          :ok

        {:DOWN, ^monitor, :process, ^worker, :normal} ->
          :ok

        {:DOWN, ^monitor, :process, ^worker, exit_reason} ->
          {:error, {:cancellation_worker_exit, exit_reason}}
      after
        @cancel_ack_timeout_ms ->
          Process.demonitor(monitor, [:flush])
          {:error, :cancellation_ack_timeout}
      end
    else
      :ok
    end
  end

  defp await_session_start(%__MODULE__{} = session) do
    receive do
      {:execution_plane_http_unary_started, ref, request_id, worker}
      when ref == session.ref and worker == session.worker ->
        {:ok, %{session | request_id: request_id}}

      {:execution_plane_http_unary_finished, ref, worker, {:ok, _result} = result}
      when ref == session.ref and worker == session.worker ->
        demonitor_session(session)
        {:ok, %{session | worker: nil, monitor: nil, completed_result: result}}

      {:execution_plane_http_unary_finished, ref, worker, {:error, result}}
      when ref == session.ref and worker == session.worker ->
        demonitor_session(session)
        {:error, result}

      {:DOWN, monitor, :process, worker, reason}
      when monitor == session.monitor and worker == session.worker ->
        {:error, {:unary_worker_exit, reason}}
    end
  end

  defp await_worker_exit(%__MODULE__{} = session) do
    receive do
      {:DOWN, monitor, :process, worker, _reason}
      when monitor == session.monitor and worker == session.worker ->
        :ok
    end
  end

  defp demonitor_session(%__MODULE__{monitor: monitor}) when is_reference(monitor) do
    Process.demonitor(monitor, [:flush])
    :ok
  end
end
