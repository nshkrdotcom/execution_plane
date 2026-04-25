# Usage

The main helper is `ExecutionPlane.Node`.

```elixir
{:ok, node} = ExecutionPlane.Node.start_link(node_id: "local-dev-node")
:ok = ExecutionPlane.Node.register_lane(ExecutionPlane.Process, server: node)
:ok = ExecutionPlane.Node.complete_registration(server: node)
```

Register the lane adapters, target verifiers, evidence sinks, and authority
verifier before admitting governed traffic.
