# `core/execution_plane_kernel`

Owns the workspace-local kernel for intent validation, route dispatch planning,
timeout coordination, and raw execution fact emission.

Wave 2 status:

- active
- validates final contracts before dispatch
- emits append-only `ExecutionEvent.v1` facts and terminal `ExecutionOutcome.v1`
- does not own durable truth or policy interpretation
