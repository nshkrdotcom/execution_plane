# Monorepo Project Map

- `./mix.exs`: Workspace root for the Execution Plane operator-facing ingress monorepo
- `./runtimes/execution_plane_operator_terminal/mix.exs`: Execution Plane operator-terminal ingress family for local, SSH, and distributed operator-facing TUIs

# AGENTS.md

## Execution Plane stack rules

- The root `mix.exs` is the lower runtime substrate package; `runtimes/execution_plane_operator_terminal/mix.exs` is a separate add-on package.
- Keep active root-compiled homes, add-on homes, and reserved sandbox homes distinct in docs.
- Do not move family-kit or product semantics into this repo. `cli_subprocess_core`, `pristine`, `prismatic`, and self-hosted runtime kits own their semantic layers above this substrate.
- The repo gate is `mix ci`.

## Temporal developer environment

Temporal CLI is implicitly available on this workstation as `temporal` for local durable-workflow development. Do not make repo code silently depend on that implicit machine state; prefer explicit scripts, documented versions, and README-tracked ergonomics work.

## Native Temporal development substrate

When Temporal runtime behavior is required, use the stack substrate in `/home/home/p/g/n/mezzanine`:

```bash
just dev-up
just dev-status
just dev-logs
just temporal-ui
```

Do not invent raw `temporal server start-dev` commands for normal work. Do not reset local Temporal state unless the user explicitly approves `just temporal-reset-confirm`.
