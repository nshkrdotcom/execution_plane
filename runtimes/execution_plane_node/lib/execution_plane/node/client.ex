defmodule ExecutionPlane.Node.Client do
  @moduledoc """
  Behaviour for the node package's current admission and one-shot dispatch API.

  This is distinct from `ExecutionPlane.Runtime.Client`, whose callbacks define
  the interactive lifecycle contract. Implementations must not claim that
  lifecycle unless they own subscription, input, status, and termination
  semantics end to end.
  """

  @callback describe(keyword()) ::
              {:ok, ExecutionPlane.Runtime.NodeDescriptor.t()} | {:error, term()}
  @callback admit(ExecutionPlane.Admission.Request.t(), keyword()) ::
              {:ok, ExecutionPlane.Admission.Decision.t()}
              | {:error, ExecutionPlane.Admission.Rejection.t()}
  @callback execute(ExecutionPlane.Admission.Request.t(), keyword()) ::
              {:ok, ExecutionPlane.ExecutionResult.t()}
              | {:error, ExecutionPlane.ExecutionResult.t()}
  @callback stream(ExecutionPlane.Admission.Request.t(), keyword()) ::
              {:ok, Enumerable.t()} | {:error, ExecutionPlane.Admission.Rejection.t()}
  @callback cancel(ExecutionPlane.ExecutionRef.t(), keyword()) :: :ok | {:error, term()}
end
