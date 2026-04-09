defmodule ExecutionPlane.KernelDispatchTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Kernel
  alias ExecutionPlane.Protocols.{HTTP, JsonRpc}
  alias ExecutionPlane.Testkit.ContractFixtures

  test "build_dispatch/2 resolves the http protocol module from the route" do
    intent = ContractFixtures.http_execution_intent()
    route = ContractFixtures.execution_route()

    assert {:ok, plan} = Kernel.build_dispatch(intent, route)
    assert plan.protocol_module == HTTP
    assert plan.route_id == route.route_id
  end

  test "build_dispatch/2 resolves the jsonrpc protocol module from the route" do
    intent = ContractFixtures.jsonrpc_execution_intent()

    route =
      ContractFixtures.execution_route()
      |> Map.from_struct()
      |> Map.put(:family, "process")
      |> Map.put(:protocol, "jsonrpc")
      |> ExecutionPlane.Contracts.ExecutionRoute.V1.new!()

    assert {:ok, plan} = Kernel.build_dispatch(intent, route)
    assert plan.protocol_module == JsonRpc
    assert plan.family == "process"
  end
end
