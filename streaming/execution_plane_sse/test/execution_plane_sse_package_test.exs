defmodule ExecutionPlaneSsePackageTest do
  use ExUnit.Case, async: true

  test "parses complete SSE events" do
    assert {[%{data: "hello"}], ""} = ExecutionPlane.SSE.parse("data: hello\n\n")
  end
end
