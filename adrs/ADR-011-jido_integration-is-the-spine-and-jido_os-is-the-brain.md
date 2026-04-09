# ADR-011: `jido_integration` Is The Spine And `jido_os` Is The Brain

## Decision

- `/home/home/p/g/n/jido_integration` owns durable truth, boundary/session descriptors, approvals, lease lineage, route selection, replay, and callback truth
- `/home/home/p/g/n/jido_os` owns authority and boundary-policy direction

Neither repo owns live Execution Plane mechanics.

## Rationale

This aligns the codebase with the clearest recent architecture documents and prevents future authority/runtime drift.
