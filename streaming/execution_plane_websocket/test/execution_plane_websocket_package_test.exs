defmodule ExecutionPlaneWebSocketPackageTest do
  use ExUnit.Case, async: true

  test "exports the lower WebSocket stream boundary" do
    assert function_exported?(ExecutionPlane.WebSocket, :stream, 4)
  end
end
