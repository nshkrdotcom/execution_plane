defmodule ExecutionPlane.Node.TargetClient.Adapter do
  @moduledoc """
  In-process Target client that dispatches through a host-registered lane adapter.
  """

  @behaviour ExecutionPlane.Target.Client

  @impl true
  def describe(opts), do: {:ok, %{lane_adapter: Keyword.get(opts, :lane_adapter)}}

  @impl true
  def execute(request, opts) do
    adapter = Keyword.fetch!(opts, :lane_adapter)

    with :ok <- adapter.validate(request) do
      adapter.execute(request, opts)
    end
  end

  @impl true
  def stream(request, opts) do
    adapter = Keyword.fetch!(opts, :lane_adapter)

    with :ok <- adapter.validate(request) do
      adapter.stream(request, opts)
    end
  end

  @impl true
  def cancel(_execution_ref, _opts), do: :ok
end
