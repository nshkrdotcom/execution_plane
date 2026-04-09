# HTTP, GraphQL, And Realtime Family Design

## End-State Ownership

The lower HTTP/realtime substrate lives in the Execution Plane, but it does not replace the semantic family kits.

Execution Plane packages used by this slice:

- `/home/home/p/g/n/execution_plane/protocols/execution_plane_http`
- `/home/home/p/g/n/execution_plane/streaming/execution_plane_sse`
- `/home/home/p/g/n/execution_plane/streaming/execution_plane_websocket`
- placement packages used for egress execution

Those packages own:

- lower HTTP request execution
- SSE framing and stream lifecycle
- WebSocket connection lifecycle
- lower egress placement
- proxy / guest / remote termination mechanics

They do not own semantic HTTP, GraphQL, or provider semantics.

## Target Repo Roles

### `/home/home/p/g/n/pristine`

After refactor:

- remains the shared HTTP semantic runtime
- emits `HttpExecutionIntent.v1`
- delegates lower execution to the Execution Plane packages
- keeps serialization, auth shaping, resilience, telemetry, and normalized response shaping

Public surface rule:

- `pristine` exposes semantic request/response APIs
- `execution_plane_http` stays an internal dependency seam, not the new public API of `pristine`

### `/home/home/p/g/n/prismatic`

After refactor:

- remains the GraphQL semantic layer
- does not own transport
- compiles GraphQL operations into HTTP execution plans
- reuses the same lower HTTP execution substrate via `pristine` or a shared lower contract path

### `/home/home/p/g/n/reqllm_next`

After refactor:

- keeps provider-family planning, model semantics, response normalization, and realtime semantics
- drops direct Finch / Mint / SSE / WebSocket transport ownership
- converges on the same lower HTTP and realtime substrate used elsewhere
- must not overload provider capability vocabulary with placement terminology

This packet does not require `reqllm_next` to become a thin wrapper over `pristine` public APIs. It requires convergence on the same lower execution substrate.

### `/home/home/p/g/n/notion_sdk` and `/home/home/p/g/n/github_ex`

After refactor:

- remain thin SDKs above `pristine`
- update docs and guides to explain the new lower execution path

### `/home/home/p/g/n/linear_sdk`

After refactor:

- remains a thin SDK above `prismatic`
- updates docs and guides to explain the new lower execution path

## Capability Waves For This Slice

### Minimal viable lane

First wave in this family slice:

- unary HTTP request/response
- shared lineage propagation
- transport failure classification

### Session-bearing lane

Follow-up wave in this slice:

- SSE stream lifecycle
- WebSocket session lifecycle
- reconnect and terminal close semantics

No repo may claim the same covered capability after its wave closes.

## Critical Rules

- GraphQL is a semantic layer, not a transport family.
- LLM providers are semantic families, not transport owners.
- WebSocket and SSE lifecycle belong to the Execution Plane, not repo-local SDK internals.
- `ExecutionSurface` remains a placement term. It must not be repurposed as provider capability vocabulary.
- HTTP semantic failures and lower transport failures must remain distinguishable.
