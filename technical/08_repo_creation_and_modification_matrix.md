# Repo Creation And Modification Matrix

## New Repo

| Path | Status | Role |
| --- | --- | --- |
| `/home/home/p/g/n/execution_plane` | new | lower execution-plane workspace and shared runtime substrate |

## Capability-Wave Legend

- `F` = provisional contract and surface freeze
- `K` = kernel and minimal package topology
- `M` = minimal viable lane prove-out and freeze closure
- `A` = dependent adoption of proven minimal lanes
- `D` = durable truth, replay, approval, identity, and session-contract alignment
- `S` = session-bearing lane convergence
- `P` = service-runtime and placement breadth
- `H` = runtime-slice conformance, failure hardening, and owner-drift audit
- `U` = downstream surface audit and documentation closure
- `x` = primary planned repo subset for that wave
- `c` = named conditional upstream scope for that wave

The matrix encodes the planned primary repo subset and the named conditional upstream scope from `technical/10_subset_complete_big_bang_execution_model.md`.

It does not attempt to encode every exceptional ADR-016 upstream touch, because those are wave-local exceptions rather than planned participation.

`citadel` is the Brain. `jido_integration` serves the public facade `Jido.Integration.V2`. `JIDO_BRAIN_CONTRACT_CONTEXT/` preserves the packet's Brain-side contract lineage.

## Repo Participation Matrix

| Repo | F | K | M | A | D | S | P | H | U |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `execution_plane` | x | x | x | c | x | x | x | x |  |
| `external_runtime_transport` |  | x |  |  |  |  | x |  |  |
| `pristine` |  |  | x | c |  |  |  | x | c |
| `prismatic` |  |  |  | x |  |  |  | x | x |
| `reqllm_next` |  |  | x | c |  | x |  | x |  |
| `cli_subprocess_core` |  |  | x | c |  | x |  | x |  |
| `codex_sdk` |  |  | x | c |  | x |  | x |  |
| `claude_agent_sdk` |  |  |  | x |  | x |  | x |  |
| `gemini_cli_sdk` |  |  |  | x |  | x |  | x |  |
| `amp_sdk` |  |  |  | x |  | x |  | x |  |
| `notion_sdk` |  |  |  | x |  |  |  |  | x |
| `github_ex` |  |  |  | x |  |  |  |  | x |
| `linear_sdk` |  |  |  | x |  |  |  |  | x |
| `agent_session_manager` | x |  |  |  | x | x |  | x |  |
| `self_hosted_inference_core` |  |  |  |  |  |  | x | x |  |
| `llama_cpp_sdk` |  |  |  |  |  |  | x | x |  |
| `jido_integration` | x |  |  |  | x | x | x | x |  |
| `citadel` | x |  |  |  | x | x |  | x |  |

## Packet Control Asset

| Path | Role |
| --- | --- |
| packet docs repo | final prompt-suite, milestone, and packet-closure target |

## Existing Repos To Modify

| Path | Action |
| --- | --- |
| `/home/home/p/g/n/pristine` | adopt lower HTTP execution substrate; keep semantic HTTP runtime ownership |
| `/home/home/p/g/n/prismatic` | adopt shared lower HTTP execution path; keep GraphQL semantics |
| `/home/home/p/g/n/notion_sdk` | update to the new `pristine` runtime contract and docs |
| `/home/home/p/g/n/github_ex` | update to the new `pristine` runtime contract and docs |
| `/home/home/p/g/n/linear_sdk` | update to the new `prismatic` runtime contract and docs |
| `/home/home/p/g/n/reqllm_next` | adopt shared HTTP/realtime execution substrate and drop repo-local transport ownership |
| `/home/home/p/g/n/cli_subprocess_core` | become a CLI family kit above Execution Plane process/runtime packages |
| `/home/home/p/g/n/codex_sdk` | adopt Execution Plane-backed exec and JSON-RPC substrate |
| `/home/home/p/g/n/claude_agent_sdk` | adopt the Execution Plane-backed common CLI lane |
| `/home/home/p/g/n/gemini_cli_sdk` | adopt the Execution Plane-backed common CLI lane |
| `/home/home/p/g/n/amp_sdk` | adopt the Execution Plane-backed common CLI lane |
| `/home/home/p/g/n/agent_session_manager` | consume execution-plane contracts without owning transport |
| `/home/home/p/g/n/self_hosted_inference_core` | adopt Execution Plane process/runtime packages while keeping service-runtime ownership |
| `/home/home/p/g/n/llama_cpp_sdk` | adopt updated service-runtime contracts |
| `/home/home/p/g/n/jido_integration` | project durable truth into execution-plane contracts; own durable boundary descriptors; expose `Jido.Integration.V2` public facade |
| `/home/home/p/g/n/citadel` | Brain kernel; authority compilation; `AuthorityDecision.v1` author; align Brain/Spine/Execution Plane split

## Existing Repo To Retire From Active Runtime Ownership

| Path | Action |
| --- | --- |
| `/home/home/p/g/n/external_runtime_transport` | remove from active architecture and absorb its concepts into `/home/home/p/g/n/execution_plane` |
