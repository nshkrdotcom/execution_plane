# Repo Quality Gate Command Matrix

## Purpose

The packet needs explicit gate commands so "all green" is operational rather than interpretive.

This file is the command source of truth for every implementation wave.

## Exact Command Sets

Use the exact command set named in the repo matrix.

Repeated command sets are intentional. The packet is removing operator guesswork, not deduplicating prose.

### `ROOT_FULL`

Run at repo root in this order:

1. `mix format`
2. `mix compile --warnings-as-errors`
3. `mix test`
4. `mix credo --strict`
5. `mix dialyzer`
6. `mix docs`

### `ROOT_NO_STATIC_ANALYSIS`

Run at repo root in this order:

1. `mix format`
2. `mix compile --warnings-as-errors`
3. `mix test`
4. `mix docs`

Use this only for repos that do not currently advertise `mix credo` and `mix dialyzer`.

### `ROOT_NO_DOCS`

Run at repo root in this order:

1. `mix format`
2. `mix compile --warnings-as-errors`
3. `mix test`
4. `mix credo --strict`
5. `mix dialyzer`

Use this only for repos that do not currently advertise `mix docs`.

### `MONOREPO_FULL`

Run at repo root in this order:

1. `mix monorepo.format`
2. `mix monorepo.compile`
3. `mix monorepo.test`
4. `mix monorepo.credo --strict`
5. `mix monorepo.dialyzer`
6. `mix monorepo.docs`

### `ARCHIVAL_ROOT`

Start from `ROOT_FULL`.

If a wave reduces the repo to an archival shell and removes tasks or code paths, rerun every task that still exists and record each skipped task explicitly as `not_applicable_after_archival_shell_reduction` in the checklist evidence section.

## Repo Matrix

| Repo | Exact gate stack | Notes |
| --- | --- | --- |
| `execution_plane` | `ROOT_NO_STATIC_ANALYSIS` | this repo currently advertises `mix docs` but not `mix credo` or `mix dialyzer` |
| `external_runtime_transport` | `ARCHIVAL_ROOT` | use full root stack while code still exists; record any archival-shell task removals explicitly |
| `pristine` | `MONOREPO_FULL` | use the root `mix monorepo.*` aliases |
| `prismatic` | `MONOREPO_FULL` | use the root `mix monorepo.*` aliases |
| `notion_sdk` | `ROOT_FULL` | root repo commands |
| `github_ex` | `ROOT_FULL` | root repo commands |
| `linear_sdk` | `ROOT_FULL` | `mix ci` is stronger but the packet source of truth remains the explicit root stack above |
| `reqllm_next` | `ROOT_FULL` | the repo also has `mix quality`; the packet source of truth remains the explicit root stack above |
| `cli_subprocess_core` | `ROOT_FULL` | root repo commands |
| `codex_sdk` | `ROOT_FULL` | root repo commands |
| `claude_agent_sdk` | `ROOT_FULL` | root repo commands |
| `gemini_cli_sdk` | `ROOT_FULL` | root repo commands |
| `amp_sdk` | `ROOT_FULL` | root repo commands |
| `agent_session_manager` | `ROOT_FULL` | root repo commands |
| `self_hosted_inference_core` | `ROOT_FULL` | root repo commands |
| `llama_cpp_sdk` | `ROOT_FULL` | root repo commands |
| `jido_harness` | `ROOT_FULL` | the repo also exposes `mix quality`; the packet source of truth remains the explicit root stack above |
| `jido_integration` | `MONOREPO_FULL` | use the root `mix monorepo.*` aliases |
| `packet_docs` | packet-local validation commands | run reference scan, stale-name scan, metadata alignment scan, and Elixir parse checks |

## Packet-Local Validation Commands

For `packet_docs`, run:

1. packet-local markdown reference scan:

   ```bash
   elixir -e 'root = File.cwd!(); files = Path.wildcard("**/*.md"); regex = ~r/`((?:prompts|technical|adrs|JIDO_BRAIN_CONTRACT_CONTEXT)\/[^`]+?\.md)`/; missing = for file <- files, {:ok, text} = File.read(file), [_, rel] <- Regex.scan(regex, text), not File.exists?(Path.join(root, rel)) do {file, rel} end; Enum.each(missing, fn {file, rel} -> IO.puts("MISSING_REF #{file} -> #{rel}") end); IO.puts("missing_count=#{length(missing)}")'
   ```

2. stale-name or stale-path scan:

   ```bash
   rg -n "03_minimal_viable_http_and_process_lanes_implementation_prompt|04_provider_and_dependent_family_adoption_of_minimal_lanes_implementation_prompt|05_session_bearing_lane_convergence_implementation_prompt|06_durable_truth_replay_approval_and_identity_alignment_implementation_prompt|08_active_owner_retirement_and_surface_cleanup_implementation_prompt|09_cross_repo_conformance_and_failure_hardening_implementation_prompt|10_final_verification_and_doc_sync_prompt|Workstream" README.md atlas.md technical adrs prompts JIDO_BRAIN_CONTRACT_CONTEXT brain_spine_execution_plane_architecture_review.md --glob '!technical/12_repo_quality_gate_command_matrix.md'
   ```

   The expected clean result is no matches.

3. packet metadata alignment scan:

   ```bash
   elixir prompts/validate_packet_metadata.exs
   ```

   The expected clean result is `packet_metadata_ok`.

   This scan must verify:

   - phase naming alignment across `prompts.txt` and `runner_config.exs`
   - prompt-file existence
   - primary target coverage in `prompts/commit-message.txt`
   - valid runner target names for every commit section
   - optional commit-section scope limited to named conditional upstream repos declared in the prompt

   If ADR-016 forces a new upstream repo outside the currently named conditional scope, amend the wave prompt, checklist, and `prompts/commit-message.txt` first, then rerun this scan.

4. `Code.string_to_quoted!/1` parse checks for `prompts/runner_config.exs`, `prompts/run_prompts.exs`, and `prompts/validate_packet_metadata.exs`:

   ```bash
   elixir -e 'for f <- ["prompts/runner_config.exs", "prompts/run_prompts.exs", "prompts/validate_packet_metadata.exs"] do File.read!(f) |> Code.string_to_quoted!() end; IO.puts("elixir_parse_ok")'
   ```

Equivalent commands are allowed if they provide the same evidence and are recorded in the checklist.

## Partial Failure Rule

If an upstream fix is needed:

- fix forward in the upstream repo during the same wave
- rerun the relevant gate stack in that upstream repo
- rerun the relevant gate stack in the impacted downstream repo
- record both runs in the checklist evidence section

## Closure Evidence Rule

Each wave checklist must record at least:

- repos actually touched
- upstream repos touched beyond the primary target list
- exact commands run
- command outcomes or summary evidence
- whether capability-local owner retirement happened in the same wave
- any substitutions for repo-local equivalent commands
