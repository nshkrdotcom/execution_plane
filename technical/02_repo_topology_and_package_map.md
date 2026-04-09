# Repo Topology And Package Map

## New Repo

Create:

- `/home/home/p/g/n/execution_plane`

This repo is a workspace-style lower execution-plane repo with these package homes:

```text
/home/home/p/g/n/execution_plane
  /core/execution_plane_contracts
  /core/execution_plane_kernel
  /protocols/execution_plane_http
  /protocols/execution_plane_jsonrpc
  /streaming/execution_plane_sse
  /streaming/execution_plane_websocket
  /placements/execution_plane_local
  /placements/execution_plane_ssh
  /placements/execution_plane_guest
  /runtimes/execution_plane_process
  /sandboxes/execution_plane_container
  /sandboxes/execution_plane_microvm
  /conformance/execution_plane_testkit
```

Not every package must ship feature-complete in the first wave. The topology exists so the architecture expresses its true axes: contracts, kernel, protocol, streaming, placement, runtime, sandbox, and conformance.

## Package Responsibilities

### `core/execution_plane_contracts`

Owns:

- shared execution-plane contracts
- versioned enums for status, failure, and capability classes
- route, event, and outcome contracts
- validation rules for cross-layer payloads
- extension and schema-evolution rules

### `core/execution_plane_kernel`

Owns:

- contract validation
- route dispatch
- transport/session supervision
- raw fact emission
- timeout, cancellation, and reconnect coordination
- capability-scoped owner retirement helpers and conformance hooks

The kernel must not own durable truth or policy interpretation.

### Protocol packages

Own:

- HTTP request/response execution at the lower transport layer
- JSON-RPC framing, correlation, and transport bindings

They do not own semantic GraphQL, provider semantics, or service-runtime readiness logic.

### Streaming packages

Own:

- SSE framing and lifecycle
- WebSocket connection lifecycle
- reconnect and close semantics at the lower transport layer

### Placement packages

Own:

- same-node placement
- SSH placement
- guest-backed placement

They must remain placement-only. They must not absorb command semantics, provider behavior, or policy authority.

### Runtime packages

Own:

- process launch and supervision
- PTY / stdio attach behavior
- long-lived runtime session mechanics
- service-backed process execution below family kits

### Sandbox packages

Own:

- stronger isolation backends when available
- translation from execution policy into runtime-specific enforcement knobs

They must document isolation strength honestly.

### Conformance package

Owns:

- contract fixtures
- route-planner conformance suites
- attach/reconnect scenarios
- cross-surface equivalence tests
- replay/idempotency tests
- failure-class fixtures
- lineage continuity assertions

## Minimal First-Cut Scope

The first executable wave must at least land:

- `execution_plane_contracts`
- `execution_plane_kernel`
- `execution_plane_http`
- `execution_plane_jsonrpc`
- `execution_plane_process`
- `execution_plane_local`
- `execution_plane_testkit`

That is the minimum package set needed to prove the final contract model across unary HTTP and basic process execution.

## Existing Repos After Refactor

Family kits:

- `/home/home/p/g/n/pristine`
- `/home/home/p/g/n/prismatic`
- `/home/home/p/g/n/cli_subprocess_core`
- `/home/home/p/g/n/self_hosted_inference_core`
- `/home/home/p/g/n/reqllm_next`

Provider and product repos:

- `/home/home/p/g/n/notion_sdk`
- `/home/home/p/g/n/github_ex`
- `/home/home/p/g/n/linear_sdk`
- `/home/home/p/g/n/codex_sdk`
- `/home/home/p/g/n/claude_agent_sdk`
- `/home/home/p/g/n/gemini_cli_sdk`
- `/home/home/p/g/n/amp_sdk`
- `/home/home/p/g/n/llama_cpp_sdk`

Orchestration and control:

- `/home/home/p/g/n/agent_session_manager`
- `/home/home/p/g/n/jido_harness`
- `/home/home/p/g/n/jido_integration`
- `/home/home/p/g/n/jido_os`

## Repo To Retire From Active Ownership

- `/home/home/p/g/n/external_runtime_transport`

Its core concepts are absorbed into `/home/home/p/g/n/execution_plane`, especially the narrow placement contract and lower process/runtime seam.
