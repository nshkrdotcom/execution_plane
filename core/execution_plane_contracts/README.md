# `core/execution_plane_contracts`

Owns the shared Execution Plane contract packet, failure taxonomy, validators,
and conformance fixtures for lineage continuity.

Current packet status:

- active
- canonical owner of the lower-boundary contract structs
- Wave 5 now enforces opaque credential-handle refs so lower intents carry
  handle-style references instead of raw secret material
- Phase 4 hardens hazmat attach and stream boundaries with
  `ExecutionPlane.AttachGrant.v1`, `ExecutionPlane.StreamBackpressure.v1`,
  `ExecutionPlane.StreamAttachRevocation.v1`, `ExecutionPlane.WorkerBudget.v1`,
  and `ExecutionPlane.NoBypassScan.v1`
- Phase 4 durable workflow activities use
  `ExecutionPlane.ActivitySideEffectIdempotency.v1` to bind tenant, actor,
  workflow, activity, lower run, execution intent, lease evidence, heartbeat
  policy, timeout policy, and retry policy. Its side-effect retry scope is
  `intent_id + idempotency_key`.
- minimal-lane family-specific payload shapes remain provisional until Wave 3
