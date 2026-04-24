# Monorepo Project Map

- `./mix.exs`: Execution Plane lower-runtime substrate workspace root.
- `./runtimes/execution_plane_operator_terminal/mix.exs`: Separate operator-terminal add-on package for local, SSH, and distributed TUIs.

## Execution Plane Stack Rules

- The root `mix.exs` is the lower runtime substrate package; it is not the only compilation root in this checkout.
- `runtimes/execution_plane_operator_terminal/mix.exs` is a separate Mix project with its own dependency surface.
- Keep active root-compiled homes, add-on homes, and reserved sandbox homes distinct in docs and release notes.
- Do not move family-kit or product semantics into this repo. `cli_subprocess_core`, `pristine`, `prismatic`, `self_hosted_inference_core`, and the self-hosted runtime kits own those semantic layers above this substrate.
- The repo gate is `mix ci`.

## Current Architecture State

- This checkout is intentionally workspace-shaped, not a flat `lib/` package dump.
- The root app compiles several capability homes through `elixirc_paths`:
  - `core/execution_plane_contracts/lib`
  - `core/execution_plane_kernel/lib`
  - `protocols/execution_plane_http/lib`
  - `protocols/execution_plane_jsonrpc/lib`
  - `streaming/execution_plane_sse/lib`
  - `streaming/execution_plane_websocket/lib`
  - `placements/execution_plane_local/lib`
  - `placements/execution_plane_ssh/lib`
  - `placements/execution_plane_guest/lib`
  - `runtimes/execution_plane_process/lib`
  - `conformance/execution_plane_testkit/lib`
- `erlexec` is owned by the lower process transport slice, not by every downstream package.
- In this repo, `erlexec` is used by `ExecutionPlane.Process.Transport` and the lower process runtime code under `runtimes/execution_plane_process`.
- The HTTP, JSON-RPC, REST, and GraphQL provider layers do not need `erlexec` directly.
- `external_runtime_transport` is retired from the target architecture; do not add or preserve active dependencies on it unless the user explicitly asks for historical compatibility work.
- The root workspace should keep Hex fallback behavior in downstream repos; local path deps are for workspace development, not a silent production assumption.

## Known Direct And Transitive Consumers Of `execution_plane`

- This list is the current top-level workspace scan from `mix.exs` files outside vendored `deps/` and `_build/`.
- Some entries depend on `execution_plane` directly.
- Some entries consume it transitively through `cli_subprocess_core`, `pristine_runtime`, or `prismatic_runtime`.
- CLI subprocess family:
  - `cli_subprocess_core`
  - `agent_session_manager`
  - `claude_agent_sdk`
  - `codex_sdk`
  - `gemini_cli_sdk`
  - `amp_sdk`
  - `prompt_runner_sdk`
- Self-hosted inference and transport family:
  - `self_hosted_inference_core`
  - `llama_cpp_sdk`
  - `reqllm_next`
- Pristine / REST-provider family:
  - `pristine/apps/pristine_runtime`
  - `pristine/apps/pristine_codegen`
  - `pristine/apps/pristine_provider_testkit`
  - `github_ex`
  - `notion_sdk`
- Prismatic / GraphQL-provider family:
  - `prismatic/apps/prismatic_runtime`
  - `prismatic/apps/prismatic_codegen`
  - `prismatic/apps/prismatic_provider_testkit`
  - `linear_sdk`
- Integration and harness consumers:
  - `stack_lab/support/citadel_spine_harness`
  - `switchyard/apps/terminal_workbench_tui`
  - `switchyard/core/workbench_daemon`
  - `switchyard/core/workbench_process_runtime`
  - `switchyard/sites/site_execution_plane`
  - `switchyard/sites/site_jido`

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
