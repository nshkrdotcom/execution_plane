# Subset-Complete Big-Bang Execution Model

## Why This Exists

The packet originally had the right target architecture but the wrong delivery shape.

Repo-by-repo convergence is too wide to verify safely.

Purely staged compatibility migration is also the wrong answer because it preserves the ownership graph the packet is trying to eliminate.

The corrected method is a subset-complete big bang:

- final-form architecture is still the only target
- work proceeds in bounded capability waves
- each wave updates every repo needed for that capability
- each wave retires the legacy owner for the covered capability before moving on

## Program Rules

- no compatibility-shim-first public architecture
- no dual-path ownership after a capability wave closes
- no next wave can depend on undefined IR or surface rules
- contract packet and public-surface rules freeze before broad adoption waves begin
- conformance is part of delivery, not cleanup
- upstream fixes are allowed within the active wave when adoption exposes an upstream defect
- the Brain is `citadel` (`/home/home/p/g/n/citadel`); `JIDO_BRAIN_CONTRACT_CONTEXT/` preserves the packet's Brain-side contract lineage

## Capability Waves

### Wave 1: Contract Packet, Surface Exposure, And Provisional Foundation Freeze

Capability subset:

- versioned contract packet
- failure taxonomy
- public-surface and carriage rules
- final package names and topology

Repo subset:

- `execution_plane`
- `jido_integration`
- `agent_session_manager`

`jido_integration` serves the public facade `Jido.Integration.V2`.

Wave gate:

- contracts, owners, and public surfaces are provisionally frozen and documented
- the same vocabulary exists in the Brain contract context (`citadel`), Spine, Execution Plane, and facade docs
- minimal-lane family intent details remain open to Wave 3 prove-out corrections

### Wave 2: Kernel And Minimal Package Topology

Capability subset:

- contract validation
- minimal route dispatch
- unary HTTP substrate
- basic process runtime substrate

Repo subset:

- `execution_plane`
- `external_runtime_transport`

Wave gate:

- `execution_plane` contains the minimal executable substrate
- covered concepts from `external_runtime_transport` are absorbed or mapped
- `external_runtime_transport` is no longer an active owner for the minimal substrate slice covered here

### Wave 3: Minimal Viable HTTP And Process Lanes Prove-Out

Capability subset:

- unary HTTP request/response
- basic process execution
- lower JSON-RPC where needed
- final-form lineage propagation
- prove-out pressure on minimal-lane intent contracts and public surfaces

Repo subset:

- `execution_plane`
- `pristine`
- `cli_subprocess_core`
- `codex_sdk`
- `reqllm_next`

Wave gate:

- the minimal lanes run on final contracts
- lower transport ownership for the covered lane is no longer repo-local
- minimal-lane contract corrections exposed by prove-out are closed here, not deferred
- the minimal-lane freeze is now stable for dependent adoption

### Wave 4: Dependent Family And Provider Adoption Of Proven Minimal Lanes

Capability subset:

- provider SDK adoption of final minimal lanes
- GraphQL adoption of final HTTP lane
- common CLI provider adoption of final process lane

Repo subset:

- `prismatic`
- `notion_sdk`
- `github_ex`
- `linear_sdk`
- `claude_agent_sdk`
- `gemini_cli_sdk`
- `amp_sdk`

Conditional upstream scope:

- `execution_plane`
- `pristine`
- `cli_subprocess_core`
- `codex_sdk`
- `reqllm_next`
- `prismatic`

Wave gate:

- dependent SDKs no longer assume legacy lower runtime owners for the covered lane
- any upstream defects exposed by adoption are fixed in the same wave, not deferred to a late cleanup pass

### Wave 5: Durable Truth, Replay, Approval, Identity, And Session Contract Alignment

Capability subset:

- durable descriptors
- route persistence
- approval lifecycle
- replay and reconciliation
- credential handles and workload identity
- callback truth
- attach, event, and outcome semantics needed by session-bearing lanes

Repo subset:

- `execution_plane`
- `jido_integration`
- `mezzanine`
- `citadel`
- `agent_session_manager`

Wave gate:

- raw execution facts and durable meaning are cleanly separated
- no raw long-lived secrets move through execution intents
- session-bearing lane contracts are frozen before session-bearing implementation begins
- Brain-side authority semantics are validated against `citadel` source

### Wave 6: Session-Bearing Lane Convergence

Capability subset:

- SSE
- WebSocket
- persistent JSON-RPC
- PTY / stdio attach
- reconnect and resume semantics

Repo subset:

- `execution_plane`
- `reqllm_next`
- `cli_subprocess_core`
- `codex_sdk`
- `claude_agent_sdk`
- `gemini_cli_sdk`
- `amp_sdk`
- `agent_session_manager`
- `jido_integration`
- `mezzanine`

`jido_integration` serves the public facade `Jido.Integration.V2`.

Conditional upstream scope:

- any upstream repo whose aligned contract semantics require correction to close the lane may be promoted under ADR-016
- Brain-side contract mismatches are resolved against `citadel` source

Wave gate:

- session-bearing lanes use the Wave 5 contract model
- old repo-local session/runtime mechanics are retired for the covered lane in this wave

### Wave 7: Service Runtime And Placement Breadth

Capability subset:

- service startup
- readiness and health facts
- attachable service sessions
- lease reuse
- local / SSH / guest placement
- honest isolation documentation

Repo subset:

- `execution_plane`
- `external_runtime_transport`
- `self_hosted_inference_core`
- `llama_cpp_sdk`
- `jido_integration`

Wave gate:

- service-runtime semantics remain above the lower substrate
- placement and isolation guarantees are documented truthfully
- any remaining active ownership in `external_runtime_transport` is retired in this wave

### Wave 8: Runtime Slice Conformance, Failure Hardening, And Owner-Drift Audit

Capability subset:

- contract conformance
- failure-class coverage
- equivalence tests
- lineage continuity
- attach/reconnect regression coverage
- runtime-facing owner-drift audit

Repo subset:

- `execution_plane`
- `pristine`
- `prismatic`
- `reqllm_next`
- `cli_subprocess_core`
- `codex_sdk`
- `claude_agent_sdk`
- `gemini_cli_sdk`
- `amp_sdk`
- `agent_session_manager`
- `self_hosted_inference_core`
- `llama_cpp_sdk`
- `jido_integration`

Wave gate:

- shared runtime behavior is mechanically enforced
- no owner drift remains in the runtime-facing slice
- if owner drift is found, it is fixed in this wave rather than deferred

### Wave 9: Downstream Surface Audit And Documentation Closure

Capability subset:

- downstream thin-SDK surface audit
- family-surface documentation closure
- downstream docs consistency and ownership clarity

Repo subset:

- `prismatic`
- `notion_sdk`
- `github_ex`
- `linear_sdk`

Conditional upstream scope:

- `pristine`
- `prismatic`
- any upstream family repo whose surface or docs block downstream closure

Wave gate:

- downstream SDKs consume the final family surfaces cleanly
- downstream docs no longer describe stale owners or stale public paths

### Wave 10: Packet And Milestone Closure

Capability subset:

- packet prompt-suite closure
- milestone closure
- packet-local consistency checks
- packet closure

Repo subset:

- packet docs repo

Wave gate:

- prompt ordering, runner metadata, and packet-local references are consistent
- major milestones are explicitly closed
- no packet-local drift remains

## Major Milestones

- `M1`: Packet frozen, contracts frozen, public surfaces frozen
- `M2`: Minimal substrate green and retired for covered minimal slice
- `M3`: Minimal lanes proven and frozen across core families
- `M4`: Durable truth, identity, and session-carriage alignment green
- `M5`: Session-bearing lanes green
- `M6`: Service-runtime and placement breadth green
- `M7`: Runtime conformance and owner-drift audit green
- `M8`: Downstream docs and packet closure green

## Non-Negotiable Safety Conditions

- never begin broad adoption before the IR and surface rules are frozen
- never treat "code exists in both places" as acceptable after the wave covering that capability closes
- never hide incomplete semantics behind a convenience alias
- never claim sandbox properties that are not actually enforced
