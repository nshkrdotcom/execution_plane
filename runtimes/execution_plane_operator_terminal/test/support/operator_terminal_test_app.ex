defmodule ExecutionPlane.OperatorTerminal.TestSupport.App do
  @moduledoc false
  use ExRatatui.App

  alias ExRatatui.Layout.Rect
  alias ExRatatui.Widgets.Paragraph

  @impl true
  def mount(opts) do
    {:ok, %{label: Keyword.get(opts, :label, "operator-terminal-test")}}
  end

  @impl true
  def render(state, frame) do
    [
      {%Paragraph{text: state.label}, %Rect{x: 0, y: 0, width: frame.width, height: frame.height}}
    ]
  end

  @impl true
  def handle_event(%ExRatatui.Event.Key{code: "q"}, state), do: {:stop, state}
  def handle_event(_event, state), do: {:noreply, state}
end
