# Monorepo Project Map

This checkout contains one non-published Mix workspace root plus eight
independently testable component source projects. The historical public
`execution_plane 0.1.0` Hex package was a Weld-generated monolith; the
canonical release shape from `0.2.0` onward is a core-only `execution_plane`
package plus separately published lane packages:

- `./mix.exs`: non-published `execution_plane_workspace` tooling root. It owns
  Blitz orchestration and must not be treated as the Hex package.
- `./core/execution_plane/mix.exs`: independently published core-only
  `execution_plane` package from version 0.2.0 onward.
- `./protocols/execution_plane_http/mix.exs`: unary HTTP lane.
- `./protocols/execution_plane_jsonrpc/mix.exs`: independently published
  JSON-RPC framing package.
- `./streaming/execution_plane_sse/mix.exs`: SSE framing and stream lane.
- `./streaming/execution_plane_websocket/mix.exs`: WebSocket lifecycle lane.
- `./runtimes/execution_plane_process/mix.exs`: independently published
  process/PTY/stdio package.
- `./runtimes/execution_plane_node/mix.exs`: lane-neutral runtime node.
- `./runtimes/execution_plane_operator_terminal/mix.exs`: operator-terminal
  add-on package for local, SSH, and distributed TUIs.

The repository root `./mix.exs` is a Mix project, but it is not a publishable
package project. It owns Blitz orchestration and Weld 0.8.4 release tooling;
neither dependency belongs in generated runtime manifests.

## Onboarding

Read `ONBOARDING.md` first for the repo's one-screen ownership, first command,
and proof path.

## Execution Plane Stack Rules

- `core/execution_plane/mix.exs` is the lower common-substrate source unit. It
  must not grow lane-heavy dependencies or runtime ownership.
- The root `mix.exs` is workspace tooling only. Blitz belongs there and must
  not be added to generated package manifests. Weld is likewise root-only
  release tooling.
- The public `execution_plane 0.2.0` package publishes directly from
  `core/execution_plane`. It must publish before
  `execution_plane_process` or `execution_plane_jsonrpc`.
- Never publish either component against `execution_plane 0.1.0`: that
  historical monolith already contains their modules and produces module
  redefinition warnings in a real Hex-resolved consumer graph.
- The selected component projects remain independently testable source units;
  canonical edits stay in those source homes, never on the projection branch.
- Lane packages and node/operator packages are separate Mix projects with
  their own dependency surfaces.
- Keep active common substrate homes, add-on homes, and reserved sandbox homes
  distinct in docs and release notes.
- Do not move family-kit or product semantics into this repo.
  `cli_subprocess_core`, `pristine`, `prismatic`,
  `self_hosted_inference_core`, and the self-hosted runtime kits own those
  semantic layers above this substrate.
- The root repo gate is `mix ci`; it first runs unconditional
  `blitz.workspace deps_get` across the eight child projects, then uses
  impact-aware Blitz selection for their package-local `mix ci` aliases.
  Fetched dependency trees are disposable checkout state, so dependency
  bootstrap must not be skipped from prior task-state evidence. Lane packages
  must also pass their package-local gate before claims are made.

## Design Intent — Effect Isolation (North Star)

Execution Plane exists to be the hard boundary between *deciding* to do
something and *actually doing it*. Everything above it (planning, governance,
semantics, product) reasons in refs and policy; this layer is the only one that
turns an approved execution request into a real OS-level effect — spawn a
process, open a PTY, run a command over SSH.

The eventuality this repo is shaped for, even where today's wiring is
co-located, is that **Execution Plane runs (optionally) as a separate BEAM
node** so side-effecting execution ("Effects") is *hard-isolated* from the
governance/planning core: fault isolation (a runaway or crashing child cannot
take down the deciding node), security isolation (the effect surface is a
distinct trust/attestation domain), and blast-radius containment (Effects run
where they can be killed, sandboxed, or placed on a different host).

That is why the substrate is built around placement, targets, attestations, and
a runtime node rather than direct calls:

- `local-erlexec-weak` is the *weak, co-located* rung — same node, `:exec.run`,
  no real isolation. It is the default today because it is finished, not because
  it is the destination.
- Verified remote/target attestations are the *strong* rung — a distinct
  node/host/sandbox whose isolation is an attested claim, not an assumption.
- `ExecutionPlane.Runtime.Client` is the frozen interactive governed-entry
  contract intended to keep callers independent of a transport or node. The
  current `execution_plane_node` package implements the older admission and
  one-shot dispatch surface as `ExecutionPlane.Node.Client`; it must not claim
  the interactive behaviour until subscription, input, status, receipt, and
  termination semantics exist end to end.

Current state vs. intent: the execution path is live and co-located
(SDK → `cli_subprocess_core` → `ExecutionPlane.Process.Transport` → erlexec).
Node separation and the strong attestation rungs are the target architecture,
not yet the default. Do not collapse this boundary for convenience (for example
re-absorbing transport into a caller); that forfeits the isolation eventuality
the whole plane exists to enable.

## Current Architecture State

- This checkout is intentionally workspace-shaped, not a flat `lib/` package
  dump.
- The selected `core/execution_plane` source app compiles all active common
  substrate modules from its conventional `core/execution_plane/lib` tree so
  released Weld can project them without source duplication. The nested
  contract, kernel, placement, and testkit directories retain ownership
  READMEs but are not additional compiler roots.
- Root-level `placements/` and `conformance/` are not active source homes for
  the package after the workspace-root correction.
- Common substrate contracts include admission, authority refs/verifiers,
  sandbox profile carriage, acceptable attestation classes, target
  descriptors/attestations/verifiers, runtime client/node descriptor,
  execution refs/requests/results/events, evidence, provenance, placement
  surfaces, and lane adapter behaviours.
- `erlexec` is owned only by `runtimes/execution_plane_process`.
- `finch` and `server_sent_events` are owned only by
  `streaming/execution_plane_sse`.
- `mint_web_socket` is owned only by
  `streaming/execution_plane_websocket`.
- `ex_ratatui` is owned only by
  `runtimes/execution_plane_operator_terminal`.
- `runtimes/execution_plane_node` depends on `core/execution_plane` only among
  Execution Plane packages. Hosts select lanes by declaring lane deps and
  registering adapters, target verifiers, evidence sinks, and authority
  verifier modules before admission opens.
- Standalone lane calls must use direct lower-lane-owner provenance. The
  current node host exposes governed one-shot calls through
  `ExecutionPlane.Node.Client`; future interactive governed callers use
  `ExecutionPlane.Runtime.Client` only once a real implementation exists.
- The node may route to verified targets but must not own fallback ladders.
  Fallback owners issue separate runtime-client calls per attestation rung.
- There is no sandbox backend behaviour. Sandbox profiles are carried as
  opaque policy data, and actual isolation claims must be verified target
  attestations.
- `local-erlexec-weak` is a weak local process attestation, not a container or
  microVM isolation guarantee.
- `external_runtime_transport` is retired from the target architecture; do not
  add or preserve active dependencies on it unless the user explicitly asks for
  historical compatibility work.
- The workspace should keep Hex fallback behavior in downstream repos;
  local path deps are for workspace development, not a silent production
  assumption.
- Publish the core-only `execution_plane` package first.
  Process, JSON-RPC, HTTP, SSE/WebSocket, node, and operator-terminal projects
  are separate publication units. A component publication proof must compile
  from a clean standalone package/checkout against the actual Hex-resolved
  core, never only against the sibling workspace path.

## Known Direct Consumers Of `execution_plane`

- This list is the current sibling scan from `mix.exs` and
  `build_support/*.exs` files outside vendored `deps/`, `_build/`, and
  generated `dist/` output.
- For local sibling development, `:execution_plane` must resolve to
  `../execution_plane/core/execution_plane` from sibling repos, or the
  equivalent relative path from nested packages. Never point `:execution_plane`
  at the repo root; the root is only `execution_plane_workspace`.
- Lane packages still resolve through their package homes:
  `protocols/execution_plane_http`, `protocols/execution_plane_jsonrpc`,
  `streaming/execution_plane_sse`, `streaming/execution_plane_websocket`,
  `runtimes/execution_plane_process`, `runtimes/execution_plane_node`, and
  `runtimes/execution_plane_operator_terminal`.
- Updated direct consumers:
  - `cli_subprocess_core`
  - `self_hosted_inference_core`
  - `llama_cpp_sdk`
  - `reqllm_next`
  - `pristine/apps/pristine_runtime`
  - `prismatic/apps/prismatic_runtime` through
    `prismatic/build_support/dependency_resolver.exs`
  - `jido_integration/core/runtime_router` through
    `jido_integration/build_support/dependency_resolver.exs`
  - `citadel/core/authority_contract`
  - `stack_lab/support/citadel_spine_harness`
- Other sibling repos still contain Execution Plane references and must be
  rechecked before active work: `switchyard` and retired
  `external_runtime_transport`.

## Temporal Developer Environment

- Temporal CLI is implicitly available on this workstation as `temporal` for local durable-workflow development.
- Do not make repo code silently depend on that implicit machine state; prefer explicit scripts, documented versions, and README-tracked ergonomics work.

## Native Temporal Development Substrate

- When Temporal runtime behavior is required, use the stack substrate in `/home/home/p/g/n/mezzanine`:

```bash
just dev-up
just dev-status
just dev-logs
just temporal-ui
```

- Do not invent raw `temporal server start-dev` commands for normal work.
- Do not reset local Temporal state unless the user explicitly approves `just temporal-reset-confirm`.

<!-- gn-ten:repo-agent:start repo=execution_plane source_sha=ab276c0640772b73065ab12bf05d77be51f1bb67 -->
# execution_plane Agent Instructions Draft

## Owns

- Lower runtime substrate.
- Execution packets.
- Lane protocols.
- Placement.
- Sandbox and target attestations.
- Raw lower evidence.

## Does Not Own

- Durable business meaning.
- Governance policy.
- Semantic routing.
- Product UX.
- Connector credential lifecycle.

## Allowed Dependencies

- GroundPlane primitives.
- Lane-specific runtime libraries when isolated to lane packages.

## Forbidden Imports

- Product modules.
- Mezzanine workflow logic.
- Citadel policy internals.
- Jido connector semantics.

## Verification

- `mix ci`
- Lane package tests for changed runtime families.

## Escalation

If a caller asks Execution Plane to infer meaning or policy, reject the change
and move that behavior to Jido Integration, Citadel, or Mezzanine.
<!-- gn-ten:repo-agent:end -->

## Blitz 0.3.0 operational note

Root workspace Blitz uses published Hex `~> 0.3.0` by default; `.blitz/` is committed compact impact state after green QC. Source and `mix.exs` changes cascade through reverse workspace dependencies; docs-only changes should stay owner-local.

## Dependency Sources And Runtime Env

- The repo-wide dependency-source manifest is
  `build_support/dependency_sources.config.exs`; the shared helper is
  `build_support/dependency_sources.exs`.
- Local dependency-source overrides belong in `.dependency_sources.local.exs`,
  which is intentionally gitignored.
- Dependency source selection must not use environment variables.
- Runtime application code under `lib/**` must not call direct OS env APIs.
  Runtime env reads belong in `config/runtime.exs` or a `Config.Provider`.
- Released Weld `~> 0.8.4` remains root-only tooling for reproducing the
  historical 0.1.0 monolith. `build_support/weld.exs` is historical release
  evidence, not the 0.2.0+ publication source. Publish the core and lane
  packages from their package directories; never make canonical source edits
  on `projection/execution_plane`.
