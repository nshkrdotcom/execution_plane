# Monorepo Project Map

This checkout contains one non-published Mix workspace root plus eight
publishable package projects:

- `./mix.exs`: non-published `execution_plane_workspace` tooling root. It owns
  Blitz orchestration and must not be treated as the Hex package.
- `./core/execution_plane/mix.exs`: publishable `execution_plane` common
  substrate.
- `./protocols/execution_plane_http/mix.exs`: unary HTTP lane.
- `./protocols/execution_plane_jsonrpc/mix.exs`: JSON-RPC framing lane.
- `./streaming/execution_plane_sse/mix.exs`: SSE framing and stream lane.
- `./streaming/execution_plane_websocket/mix.exs`: WebSocket lifecycle lane.
- `./runtimes/execution_plane_process/mix.exs`: process/PTY/stdio lane.
- `./runtimes/execution_plane_node/mix.exs`: lane-neutral runtime node.
- `./runtimes/execution_plane_operator_terminal/mix.exs`: operator-terminal
  add-on package for local, SSH, and distributed TUIs.

The repository root `./mix.exs` is a Mix project, but it is not a publishable
package project. It is allowed to depend on Blitz for repo-wide orchestration;
publishable manifests are not.

## Execution Plane Stack Rules

- `core/execution_plane/mix.exs` is the lower common substrate package. It
  must not grow lane-heavy dependencies or runtime ownership.
- The root `mix.exs` is workspace tooling only. Blitz belongs there and must
  not be added to publishable package manifests.
- Lane packages and node/operator packages are separate Mix projects with
  their own dependency surfaces.
- Keep active common substrate homes, add-on homes, and reserved sandbox homes
  distinct in docs and release notes.
- Do not move family-kit or product semantics into this repo.
  `cli_subprocess_core`, `pristine`, `prismatic`,
  `self_hosted_inference_core`, and the self-hosted runtime kits own those
  semantic layers above this substrate.
- The root repo gate is `mix ci`; it uses Blitz to run package-local `mix ci`
  aliases. Lane packages must also pass their package-local gate before claims
  are made.

## Current Architecture State

- This checkout is intentionally workspace-shaped, not a flat `lib/` package
  dump.
- The publishable `core/execution_plane` app compiles only common substrate
  homes through `elixirc_paths`. From the repo root those active homes are:
  - `core/execution_plane/lib`
  - `core/execution_plane/core/execution_plane_contracts/lib`
  - `core/execution_plane/core/execution_plane_kernel/lib`
  - `core/execution_plane/placements/execution_plane_local/lib`
  - `core/execution_plane/placements/execution_plane_ssh/lib`
  - `core/execution_plane/placements/execution_plane_guest/lib`
  - `core/execution_plane/conformance/execution_plane_testkit/lib`
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
- Standalone lane calls must use direct lower-lane-owner provenance. Governed
  execution callers must use `ExecutionPlane.Runtime.Client`.
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
- Publish `core/execution_plane` first, lane packages next,
  `execution_plane_node` after the lane/common contracts it depends on, and
  `execution_plane_operator_terminal` last.

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
