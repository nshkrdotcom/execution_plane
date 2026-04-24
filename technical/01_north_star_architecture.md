# North-Star Architecture

## The Three Layers

### Brain

Repo:

- `/home/home/p/g/n/citadel`

Owns:

- reasoning authority
- policy compilation
- boundary-class and trust-profile decisions
- approval policy direction
- workload-topology intent
- authored `AuthorityDecision.v1` contracts
- `BoundaryIntent`, `TopologyIntent`, `InvocationRequest.V2`
- `KernelSnapshot`, `SignalIngress`, `BoundaryLeaseTracker`
- bridges to `jido_integration` and `outer_brain`

Must not own:

- live transport processes
- HTTP clients
- subprocess, socket, or stream lifecycle
- durable run or attempt truth
- lower execution facts
- memory storage or proof-token ownership

### Spine

Repo:

- `/home/home/p/g/n/jido_integration`

Owns:

- durable boundary/session truth
- route selection and route persistence
- lease lineage and approval state
- run / attempt / event persistence
- replay and reconciliation
- async dispatch and callback truth
- projection of Brain-authored intent into Execution Plane contracts
- durable `BoundarySessionDescriptor.v1`
- durable meaning applied to raw execution facts

Must not own:

- live lower runtime mechanics
- protocol framing
- transport adapters
- subprocess or socket lifecycle
- family-kit semantic public APIs

### Execution Plane

Repo:

- `/home/home/p/g/n/execution_plane`

Owns:

- live external I/O
- protocol bindings and framing
- transport lifecycle and connection state
- placement drivers
- sandbox/runtime adapters
- live attach / reconnect / teardown mechanics
- raw execution events and raw execution outcomes

Must not own:

- durable boundary/session truth
- approval state or lease issuance
- credential issuance
- semantic provider behavior
- family-specific normalization above raw outcomes
- reasoning authority

## Layers Above The Execution Plane

Family kits that stay above the Execution Plane:

- `/home/home/p/g/n/pristine`
- `/home/home/p/g/n/prismatic`
- `/home/home/p/g/n/cli_subprocess_core`
- `/home/home/p/g/n/self_hosted_inference_core`
- `/home/home/p/g/n/reqllm_next`

Provider and product repos that stay above those family kits:

- `/home/home/p/g/n/notion_sdk`
- `/home/home/p/g/n/github_ex`
- `/home/home/p/g/n/linear_sdk`
- `/home/home/p/g/n/codex_sdk`
- `/home/home/p/g/n/claude_agent_sdk`
- `/home/home/p/g/n/gemini_cli_sdk`
- `/home/home/p/g/n/amp_sdk`
- `/home/home/p/g/n/llama_cpp_sdk`

Orchestration repos that remain above or beside those layers:

- `/home/home/p/g/n/agent_session_manager`

Durable substrate, semantic runtime, and product boundary (above Spine):

- `/home/home/p/g/n/mezzanine` — durable business-semantics substrate; Temporal workflow runtime; PackModel; lifecycle/execution/decision engines; promotion coordinator; proof tokens; audit
- `/home/home/p/g/n/outer_brain` — semantic-runtime gateway; recall orchestration; private memory write; context pack; SemanticProvider contract
- `/home/home/p/g/n/app_kit` — northbound product boundary; `mix app_kit.no_bypass` enforcement; operator/work/review surfaces
- `/home/home/p/g/n/extravaganza` — product proving ground; thin product above AppKit

Cross-cutting infrastructure:

- `/home/home/p/g/n/ground_plane` — shared lower primitives; Postgres helpers; projection
- `/home/home/p/g/n/AITrace` — unified observability; Trace/Span/Event/Collector
- `/home/home/p/g/n/stack_lab` — proof composition; cross-repo harnesses; does not replace owner quality gates

## Hard Rules

- No repo above the Execution Plane may own transport reality.
- No repo below the Spine may own durable boundary/session truth.
- `citadel` is the Brain and owns authority and policy direction.
- The Execution Plane owns execution facts, not durable execution truth.
- Semantic family kits must not be flattened into the Execution Plane.
- `jido_integration` carries contracts but must not turn the Execution Plane into the public product API.
- `mezzanine` owns Temporal. Use `just dev-up` in `/p/g/n/mezzanine`; do not use raw `temporal server start-dev`.
- `app_kit` is the product boundary. Product code must pass `mix app_kit.no_bypass`.
- `outer_brain` must not own governed writes, access graph mutation, or proof tokens.
- Memory updates are supersession, never mutation: new rows with parent links; existing provenance is immutable.
- All durable memory, policy, proof, graph, and audit state stays in Elixir-owned Postgres transactions; external services compute but do not govern.

## Distributed Semantics Rule

The authoritative architecture is async-first:

- the Brain authors decisions
- the Spine persists durable meaning
- the Execution Plane emits execution facts
- sync facades may exist above that core for UX and product ergonomics

Attach, reconnect, approval, timeout, callback, and replay behavior are state-machine problems, not simple call-return problems.

## Isolation Rule

Execution placement and sandbox strength are policy dimensions, not naming assumptions.

The architecture must distinguish at least:

- execution placement policy
- network policy
- filesystem/workspace policy
- credential/secret policy
- capability/approval/audit policy

## Delivery Rule

The target remains final-form architecture.

Implementation proceeds through capability waves, not repo silos:

- every wave has a bounded functionality subset
- every wave has a bounded repo subset
- every completed wave retires legacy ownership for the covered capability
- no wave may leave permanent dual-path ownership behind
