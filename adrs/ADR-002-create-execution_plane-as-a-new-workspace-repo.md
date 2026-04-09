# ADR-002: Create `execution_plane` As A New Workspace Repo

## Decision

Create:

- `/home/home/p/g/n/execution_plane`

as the unified lower execution-plane workspace.

## Rationale

`/home/home/p/g/n/external_runtime_transport` is too narrow for the full HTTP, realtime, process, and service-runtime target.

The architecture needs one explicit lower runtime home rather than more piecemeal expansions of older repos, and `execution_plane` is a better long-term name than `hazmat`.

The workspace topology is intentionally axis-based:

- contracts
- kernel
- protocols
- streaming
- placement
- runtimes
- sandboxes
- conformance
