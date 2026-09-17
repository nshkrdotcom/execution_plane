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
end
