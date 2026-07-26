defmodule ExecutionPlane.Node.LocalClient do
  @moduledoc """
  Same-node implementation of `ExecutionPlane.Node.Client`.

  This module owns the node package's current admission and one-shot dispatch
  API. It does not implement the interactive `ExecutionPlane.Runtime.Client`
  lifecycle.
  """

  @behaviour ExecutionPlane.Node.Client

  @impl true
  def describe(opts \\ []), do: ExecutionPlane.Node.describe(opts)

  @impl true
  def admit(request, opts \\ []), do: ExecutionPlane.Node.admit(request, opts)

  @impl true
  def execute(request, opts \\ []), do: ExecutionPlane.Node.execute(request, opts)

  @impl true
  def stream(request, opts \\ []), do: ExecutionPlane.Node.stream(request, opts)

  @impl true
  def cancel(execution_ref, opts \\ []), do: ExecutionPlane.Node.cancel(execution_ref, opts)
end
