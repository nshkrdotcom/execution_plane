# `core/execution_plane_kernel`

Owns the workspace-local kernel for intent validation, route dispatch planning,
timeout coordination, and raw execution fact emission.

Wave 2 status:

- active
- validates final contracts before dispatch
- emits append-only `ExecutionEvent.v1` facts and terminal `ExecutionOutcome.v1`
- does not own durable truth or policy interpretation

## Persistence Documentation

See `docs/persistence.md` for tiers, defaults, adapters, unsupported selections, config examples, restart claims, durability claims, debug sidecar behavior, redaction guarantees, migration or preflight behavior, and no-bypass scope when applicable.
