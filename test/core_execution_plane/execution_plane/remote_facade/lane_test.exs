defmodule ExecutionPlane.RemoteFacade.LaneTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.RemoteFacade.Lane

  test "declares owner-defined lane group" do
    assert Lane.owner_group() == {Lane, :lane}
  end

  test "executes diagnostic lane and returns serializable result" do
    assert {:ok, result} = Lane.execute_lane(valid_request())

    assert result["execution_ref"] == "execution://one"
    assert result["status"] == "succeeded"
    assert get_in(result, ["output", "diagnostic_result", "payload", "message"]) == "hello"
  end

  test "returns structured failure for invalid diagnostic request" do
    assert {:error, result} =
             valid_request()
             |> Map.put("lane_id", "unsupported")
             |> Lane.execute_lane()

    assert result["status"] == "failed"
    assert result["execution_ref"] == "execution://one"
  end

  defp valid_request do
    %{
      "execution_ref" => "execution://one",
      "lane_id" => "diagnostic",
      "operation" => "diagnostic.echo",
      "payload" => %{"message" => "hello"},
      "metadata" => %{
        "tenant_ref" => "tenant://one",
        "trace_ref" => "trace://one",
        "idempotency_key" => "idem://one"
      }
    }
  end
end
