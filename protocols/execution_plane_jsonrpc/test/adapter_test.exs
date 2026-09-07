defmodule ExecutionPlane.JsonRpc.AdapterTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Protocols.JsonRpc.Adapter

  test "adapter: request IDs advance and explicit IDs survive framing" do
    {:ok, state, []} = Adapter.init(request_id_start: 1)
    assert {:ok, 1, frame, state} = Adapter.encode_request({"ping", %{value: 42}}, state)
    assert Jason.decode!(frame) == %{"id" => 1, "method" => "ping", "params" => %{"value" => 42}}
    assert String.ends_with?(frame, "\n")
    assert {:ok, 2, _, state} = Adapter.encode_request("ping", state)

    assert {:ok, "opaque-id", frame, _} =
             Adapter.encode_request(%{id: "opaque-id", method: "ping"}, state)

    assert Jason.decode!(frame)["id"] == "opaque-id"
  end

  test "adapter: inbound responses and peer requests preserve correlation" do
    {:ok, state, []} = Adapter.init(request_id_start: 1)

    assert {:ok, [{:response, "id", {:ok, false}}], ^state} =
             Adapter.handle_inbound(~s({"id":"id","result":false}), state)

    assert {:ok, [{:peer_request, 0, request}], ^state} =
             Adapter.handle_inbound(~s({"id":0,"method":"approve"}), state)

    assert request["method"] == "approve"
  end

  test "adapter: invalid frames and requests return structured errors" do
    {:ok, state, []} = Adapter.init(request_id_start: 1)

    assert {:ok, [{:protocol_error, {:invalid_json, _}}], ^state} =
             Adapter.handle_inbound("{", state)

    assert {:ok, [{:protocol_error, {:invalid_json_rpc_message, []}}], ^state} =
             Adapter.handle_inbound("[]", state)

    assert {:error, {:invalid_request, 42}} = Adapter.encode_request(42, state)
    assert {:error, {:invalid_notification, 42}} = Adapter.encode_notification(42, state)
  end

  test "adapter: peer replies preserve false results and structured errors" do
    {:ok, state, []} = Adapter.init(request_id_start: 1)
    assert {:ok, frame, ^state} = Adapter.encode_peer_reply(0, {:ok, false}, state)
    assert Jason.decode!(frame) == %{"id" => 0, "result" => false}

    assert {:ok, frame, ^state} =
             Adapter.encode_peer_reply("id", {:error, :unsupported_peer_request}, state)

    assert Jason.decode!(frame)["error"]["code"] == -32_601
  end
end
