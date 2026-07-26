# Usage

The main helper is `ExecutionPlane.Node`; `ExecutionPlane.Node.LocalClient`
implements the package's current `ExecutionPlane.Node.Client` admission and
one-shot dispatch behavior.

```elixir
{:ok, node} = ExecutionPlane.Node.start_link(node_id: "local-dev-node")
:ok = ExecutionPlane.Node.register_lane(ExecutionPlane.Process, server: node)
:ok = ExecutionPlane.Node.complete_registration(server: node)
```

Register the lane adapters, target verifiers, evidence sinks, and authority
verifier before admitting governed traffic.

`ExecutionPlane.Runtime.Client` is a separate interactive lifecycle contract.
Do not present this package's synchronous `execute/stream` surface as an
implementation until a node host owns subscription, input, status, receipt,
and termination semantics end to end.
