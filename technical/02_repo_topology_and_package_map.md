# Repo Topology And Package Map

## Repo

`/home/home/p/g/n/execution_plane` is a workspace-style lower
execution-plane repo with common substrate homes, lane package homes, node
runtime homes, and reserved future target/sandbox homes.

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
  /runtimes/execution_plane_node
  /runtimes/execution_plane_operator_terminal
  /sandboxes/execution_plane_container
  /sandboxes/execution_plane_microvm
  /targets/execution_plane_remote_agent
  /conformance/execution_plane_testkit
```

The active Mix-project set is intentionally smaller than the directory
topology. Reserved directories document future axes without creating
compatibility packages or unimplemented public APIs.

## Exact Mix Projects

The checkout contains exactly eight Mix projects:

- `mix.exs`: root `execution_plane` common substrate
- `protocols/execution_plane_http/mix.exs`
- `protocols/execution_plane_jsonrpc/mix.exs`
- `streaming/execution_plane_sse/mix.exs`
- `streaming/execution_plane_websocket/mix.exs`
- `runtimes/execution_plane_process/mix.exs`
- `runtimes/execution_plane_node/mix.exs`
- `runtimes/execution_plane_operator_terminal/mix.exs`

## Package Responsibilities

### `core/execution_plane_contracts`

Owns:

- shared execution-plane contracts
- admission, authority, sandbox-profile, acceptable-attestation, target,
  runtime-client, lane-adapter, execution, event, evidence, and provenance
  values
- canonical JSON codecs for remote-boundary values
- versioned enums for status, failure, and capability classes
- route, event, and outcome contracts
- validation rules for cross-layer payloads
- extension and schema-evolution rules

### `core/execution_plane_kernel`

Owns:

- contract validation
- pure route and dispatch planning
- raw fact emission
- capability-scoped owner retirement helpers and conformance hooks

The kernel must not own durable truth or policy interpretation.

### Protocol packages

Own:

- HTTP request/response execution at the lower transport layer
- JSON-RPC framing, correlation, and transport bindings

They do not own semantic GraphQL, provider semantics, subprocess launch, or
service-runtime readiness logic.

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
- separately consumable operator-terminal ingress for operator-facing TUIs
- lane-neutral node admission and target routing

### Sandbox packages

Own:

- reserved future stronger-isolation implementations when backed by real
  verifiers and target protocol evidence
- documentation of isolation posture

They must document isolation strength honestly. The current root substrate has
no sandbox backend behaviour; it carries opaque sandbox profiles and
acceptable-attestation classes only.

### Target packages

Own:

- future remote-agent target protocol implementations
- cryptographic or otherwise externally backed target attestation
- target-client implementations that remain outside the lane-neutral node

### Conformance package

Owns:

- contract fixtures
- route-planner conformance suites
- attach/reconnect scenarios
- cross-surface equivalence tests
- replay/idempotency tests
- failure-class fixtures
- lineage continuity assertions

## Active Root Package Scope

The root `execution_plane` Mix package compiles common substrate homes only:

- `execution_plane_contracts`
- `execution_plane_kernel`
- `execution_plane_local`
- `execution_plane_ssh`
- `execution_plane_guest`
- `execution_plane_testkit`

The HTTP, JSON-RPC, SSE, WebSocket, process, node, and operator-terminal
surfaces are separate Mix projects. The node package depends on root
`execution_plane` but does not require any lane package. Hosts choose lanes by
declaring lane deps and registering adapters.

Sandbox homes remain reserved topology homes until their isolation guarantees
are implemented and tested.

## Current Runtime Model

Standalone lane owners may execute directly with
`direct_lower_lane_owner` provenance. Governed callers use
`ExecutionPlane.Runtime.Client`.

The node validates authority references through a host-registered verifier,
intersects `AcceptableAttestation` classes with verified targets, chooses one
target for one execute call, dispatches through a registered lane adapter,
and emits serializable evidence. It does not perform fallback. Brain/Spine
owners that allow multiple attestation classes own the fallback ladder by
issuing separate runtime-client calls.

`local-erlexec-weak` is the current local process attestation class. It is
honest weak local execution, not a sandbox isolation claim.

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
- `/home/home/p/g/n/jido_integration` (Spine; public facade `Jido.Integration.V2`)
- `/home/home/p/g/n/citadel` (Brain; authority compilation; `AuthorityDecision.v1` author)

Durable substrate, semantic runtime, and product boundary:

- `/home/home/p/g/n/mezzanine` (Temporal; PackModel; lifecycle/execution/decision engines; promotion; audit)
- `/home/home/p/g/n/outer_brain` (semantic runtime; recall; context pack; SemanticProvider)
- `/home/home/p/g/n/app_kit` (northbound product boundary; `mix app_kit.no_bypass`)
- `/home/home/p/g/n/extravaganza` (product proving ground)
- `/home/home/p/g/n/ground_plane` (shared lower primitives; Postgres/projection helpers)
- `/home/home/p/g/n/AITrace` (unified observability)
- `/home/home/p/g/n/stack_lab` (proof composition)

## Repo To Retire From Active Ownership

- `/home/home/p/g/n/external_runtime_transport`

Its core concepts are absorbed into `/home/home/p/g/n/execution_plane`, especially the narrow placement contract and lower process/runtime seam.
