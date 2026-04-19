# Execution Plane

<p align="center">
  <img src="assets/execution_plane.svg" width="200" height="200" alt="Execution Plane logo">
</p>

Execution Plane is the lower runtime workspace in the active lower-gateway /
lower-runtime split:

- lower acceptance gateway: `jido_integration`
- lower runtime owner: this repo

Waves 2, 3, 6, and 7 turn the Wave 1 shell into the executable lower substrate
used across the stack: the contract packet stays frozen, the kernel, placement,
HTTP, process, and minimal JSON-RPC packages execute on the final contracts,
and the repo now exposes frozen helper surfaces for unary HTTP, one-shot
process execution, long-lived process transport, and truthful local, SSH, and
guest placement breadth.

The operator-terminal ingress lane is part of the Execution Plane repo, but it
now lives in a separate add-on package,
`runtimes/execution_plane_operator_terminal`, so base lower-runtime consumers
do not inherit `ex_ratatui` unless they explicitly opt into that lane.

## Documentation Menu

### Start Here

- [Guide Index](guides/index.md)
- [North-Star Architecture](technical/01_north_star_architecture.md)
- [Repo Topology And Package Map](technical/02_repo_topology_and_package_map.md)
- [Shared Contracts And Lineage](technical/03_shared_contracts_and_lineage.md)
- [HTTP, GraphQL, And Realtime Family Design](technical/04_http_graphql_and_realtime_family_design.md)
- [Process And Agent Session Family Design](technical/05_process_and_agent_session_family_design.md)
- [Brain, Spine, And Harness Alignment](technical/07_brain_spine_and_harness_alignment.md)
- [Subset-Complete Big-Bang Execution Model](technical/10_subset_complete_big_bang_execution_model.md)
- [Surface Exposure And Contract Carriage Matrix](technical/11_surface_exposure_and_contract_carriage_matrix.md)
- [Repo Quality Gate Command Matrix](technical/12_repo_quality_gate_command_matrix.md)

### Brain Contract Context

- [Brain Contract Context](JIDO_BRAIN_CONTRACT_CONTEXT/README.md)
- [AuthorityDecision.v1 Packet Baseline](JIDO_BRAIN_CONTRACT_CONTEXT/01_authority_decision_v1_packet_baseline.md)

### Required ADRs

- [ADR-001](adrs/ADR-001-brain-spine-execution-plane-is-the-top-level-system-split.md)
- [ADR-002](adrs/ADR-002-create-execution_plane-as-a-new-workspace-repo.md)
- [ADR-003](adrs/ADR-003-share-lineage-and-route-contracts-not-one-mega-struct.md)
- [ADR-004](adrs/ADR-004-pristine-remains-the-http-family-kit.md)
- [ADR-006](adrs/ADR-006-reqllm_next-adopts-the-shared-http-and-realtime-family.md)
- [ADR-007](adrs/ADR-007-cli_subprocess_core-remains-the-cli-family-kit-above-execution-plane.md)
- [ADR-008](adrs/ADR-008-provider-sdks-keep-provider-semantics-and-drop-runtime-ownership.md)
- [ADR-009](adrs/ADR-009-asm-remains-the-agent-session-kernel-and-jido_harness-remains-a-facade.md)
- [ADR-011](adrs/ADR-011-jido_integration-is-the-spine-and-jido_os-is-the-brain.md)
- [ADR-012](adrs/ADR-012-no-staged-compatibility-shims-or-intermediate-public-apis.md)
- [ADR-014](adrs/ADR-014-execute-the-program-as-subset-complete-capability-waves.md)
- [ADR-015](adrs/ADR-015-public-surfaces-expose-mapped-family-and-facade-irs-not-raw-execution-plane-packages.md)
- [ADR-016](adrs/ADR-016-upstream-fixes-are-allowed-within-the-active-wave.md)

## Workspace Status

Waves 2, 3, 6, and 7 now own:

- the versioned contract packet
- route validation and dispatch planning
- timeout coordination and raw-fact emission in `execution_plane_kernel`
- unary HTTP execution in `execution_plane_http`
- basic local process execution in `execution_plane_process`
- long-lived process transport and attachable process sessions in `execution_plane_process`
- operator-terminal ingress in `execution_plane_operator_terminal`
- minimal unary JSON-RPC over the process runtime in `execution_plane_jsonrpc`
- frozen helper surfaces in `ExecutionPlane.HTTP`, `ExecutionPlane.Process`, and `ExecutionPlane.JsonRpc`
- prove-out corrections to the minimal-lane intent contracts exposed by downstream adoption
- the narrow placement seam in `execution_plane_local`
- SSH-backed placement helpers in `execution_plane_ssh`
- guest-backed placement helpers in `execution_plane_guest`
- conformance fixtures and lower-substrate execution coverage in `execution_plane_testkit`
- honest documentation that container and microVM package homes are not active sandbox guarantees yet

The minimum executable package homes for the substrate slice are:

- `core/execution_plane_contracts`
- `core/execution_plane_kernel`
- `protocols/execution_plane_http`
- `protocols/execution_plane_jsonrpc`
- `placements/execution_plane_local`
- `placements/execution_plane_ssh`
- `placements/execution_plane_guest`
- `runtimes/execution_plane_process`
- `runtimes/execution_plane_operator_terminal`
- `conformance/execution_plane_testkit`

Reserved package homes for later waves are still tracked so topology and ownership stop drifting:

- `streaming/execution_plane_sse`
- `streaming/execution_plane_websocket`
- `sandboxes/execution_plane_container`
- `sandboxes/execution_plane_microvm`

## Development

```bash
mix deps.get
mix format
mix compile --warnings-as-errors
mix test
mix docs
```

The repo gate for `execution_plane` is `ROOT_NO_STATIC_ANALYSIS` from
[`technical/12_repo_quality_gate_command_matrix.md`](technical/12_repo_quality_gate_command_matrix.md).

Wave 3 proves the covered minimal-lane adoption used by `pristine`,
`cli_subprocess_core`, `codex_sdk`, and `reqllm_next`, and freezes the helper
surfaces those repos consume instead of re-owning transport.

Wave 7 closes the remaining active-owner gap from
`/home/home/p/g/n/external_runtime_transport`. That repo is no longer part of
the active ownership story for service-runtime placement or long-lived
transport mechanics.

## License

MIT

## Temporal developer environment

Temporal CLI is expected to be available as `temporal` on this developer workstation for local durable-workflow development. Current provisioning is machine-level dotfiles setup, not a repo-local dependency.

TODO: make Temporal ergonomics explicit for developers by adding repo-local setup scripts, version expectations, and fallback instructions so the tool is not silently assumed from the workstation.

## Native Temporal development substrate

Temporal runtime development is managed from `/home/home/p/g/j/jido_brainstorm` through the repo-owned `just` workflow, not by manually starting ad hoc Temporal processes.

Use:

```bash
cd /home/home/p/g/j/jido_brainstorm
just dev-up
just dev-status
just dev-logs
just temporal-ui
```

Expected local contract: `127.0.0.1:7233`, UI `http://127.0.0.1:8233`, namespace `default`, native service `temporal-dev.service`, persistent state `~/.local/share/temporal/dev-server.db`.
