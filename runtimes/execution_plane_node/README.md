# Execution Plane Node

`execution_plane_node` is the lane-neutral control-plane runtime. Hosts select
lane adapters, Target verifiers, evidence sinks, and the authority verifier by
declaring their own dependencies and registering those modules before admission
is opened.

The package depends on root `execution_plane` only. It does not require
`execution_plane_process`, `execution_plane_http`, `execution_plane_sse`,
`execution_plane_websocket`, or `execution_plane_jsonrpc`.

## Startup Contract

A host starts the node, registers every module that defines the host's runtime
surface, and only then completes registration:

```elixir
{:ok, node} = ExecutionPlane.Node.start_link(node_id: "local-dev-node")

:ok = ExecutionPlane.Node.register_lane(node, MyProcessLane, [])
:ok = ExecutionPlane.Node.register_target_verifier(node, MyTargetVerifier, [])
:ok = ExecutionPlane.Node.register_evidence_sink(node, MyEvidenceSink, [])
:ok = ExecutionPlane.Node.register_authority_verifier(node, MyAuthorityVerifier, [])
:ok = ExecutionPlane.Node.complete_registration(node, [])
```

Admission before registration completion is rejected. Governed admission with
no registered authority verifier is rejected. A node may start with zero
verified targets, but governed execution is rejected until at least one target
attests successfully.

## Routing Contract

Each governed request carries:

- an authority reference verified by the host authority verifier
- an opaque sandbox profile
- acceptable attestation classes
- placement and runtime constraints
- execution provenance

The node verifies target attestations through registered target verifiers and
only routes to descriptors that survive verification. It intersects the
request's acceptable-attestation classes with verified targets, selects one
target, dispatches through the target client and lane adapter, and emits
serializable evidence.

One execute call is one dispatch attempt. The node does not perform an
internal fallback ladder and never silently downgrades from a stronger class to
`local-erlexec-weak`. Owners such as JidoIntegration must issue separate
runtime-client execute calls for each fallback rung and record the rejection
or success of each call.

## Local Weak Target

The process-lane helper target can attest `local-erlexec-weak` for local
development and proof harnesses. That class means weak local process execution;
it is not a sandbox, container, microVM, or cryptographic isolation claim.
