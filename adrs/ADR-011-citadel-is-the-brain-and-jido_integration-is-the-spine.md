# ADR-011: `citadel` Is The Brain And `jido_integration` Is The Spine

## Decision

- `/home/home/p/g/n/citadel` owns authority compilation, installation revision, host ingress, policy packs, `BoundaryIntent`, `TopologyIntent`, `InvocationRequest.V2`, `KernelSnapshot`, `SignalIngress`, `BoundaryLeaseTracker`, and authors `AuthorityDecision.v1`
- `/home/home/p/g/n/jido_integration` owns durable truth, boundary/session descriptors, approvals, lease lineage, route selection, replay, and callback truth

Neither repo owns live Execution Plane mechanics.

## Rationale

This aligns the codebase with the current architecture and prevents authority/runtime drift.

## Scope Update (2026-04-24)

`citadel` is the Brain repo. It must not own memory storage or proof-token ownership.

`mezzanine` is the durable business-semantics substrate; it owns PackModel, lifecycle/execution/decision engines, Temporal workflow runtime, promotion coordinator, and retrospective audit.

The rule that neither repo owns live Execution Plane mechanics continues to apply to `citadel` and `mezzanine`.
