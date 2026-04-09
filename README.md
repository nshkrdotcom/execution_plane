# Execution Plane

<p align="center">
  <img src="assets/execution_plane.svg" width="200" height="200" alt="Execution Plane logo">
</p>

Execution Plane is the lower runtime workspace in the Brain / Spine / Execution Plane split:

- Brain: `jido_os`
- Spine: `jido_integration`
- Execution Plane: this repo

Wave 1 turns this repo from a single-app placeholder into a workspace-style shell with frozen package homes, the normative contract packet, the failure taxonomy, and contract-carriage rules that later waves must honor.

## Documentation Menu

### Start Here

- [Guide Index](guides/index.md)
- [North-Star Architecture](technical/01_north_star_architecture.md)
- [Repo Topology And Package Map](technical/02_repo_topology_and_package_map.md)
- [Shared Contracts And Lineage](technical/03_shared_contracts_and_lineage.md)
- [Brain, Spine, And Harness Alignment](technical/07_brain_spine_and_harness_alignment.md)
- [Subset-Complete Big-Bang Execution Model](technical/10_subset_complete_big_bang_execution_model.md)
- [Surface Exposure And Contract Carriage Matrix](technical/11_surface_exposure_and_contract_carriage_matrix.md)
- [Repo Quality Gate Command Matrix](technical/12_repo_quality_gate_command_matrix.md)

### Brain Contract Context

- [Brain Contract Context](JIDO_BRAIN_CONTRACT_CONTEXT/README.md)
- [AuthorityDecision.v1 Packet Baseline](JIDO_BRAIN_CONTRACT_CONTEXT/01_authority_decision_v1_packet_baseline.md)

### Wave 1

- [Master Orchestrator Prompt](prompts/00_master_orchestrator_prompt.md)
- [Wave 1 Checklist](prompts/01_contract_packet_and_execution_plane_foundation_checklist.md)
- [Wave 1 Implementation Prompt](prompts/01_contract_packet_and_execution_plane_foundation_implementation_prompt.md)

### Required ADRs

- [ADR-001](adrs/ADR-001-brain-spine-execution-plane-is-the-top-level-system-split.md)
- [ADR-002](adrs/ADR-002-create-execution_plane-as-a-new-workspace-repo.md)
- [ADR-003](adrs/ADR-003-share-lineage-and-route-contracts-not-one-mega-struct.md)
- [ADR-009](adrs/ADR-009-asm-remains-the-agent-session-kernel-and-jido_harness-remains-a-facade.md)
- [ADR-011](adrs/ADR-011-jido_integration-is-the-spine-and-jido_os-is-the-brain.md)
- [ADR-012](adrs/ADR-012-no-staged-compatibility-shims-or-intermediate-public-apis.md)
- [ADR-014](adrs/ADR-014-execute-the-program-as-subset-complete-capability-waves.md)
- [ADR-015](adrs/ADR-015-public-surfaces-expose-mapped-family-and-facade-irs-not-raw-execution-plane-packages.md)
- [ADR-016](adrs/ADR-016-upstream-fixes-are-allowed-within-the-active-wave.md)

## Workspace Status

Wave 1 freezes:

- the versioned contract packet
- the failure taxonomy
- the public-surface and contract-carriage rules
- the final package topology
- provisionally, the family-facing minimal-lane intent shapes pending Wave 3 prove-out

The minimal executable package homes now tracked in this repo are:

- `core/execution_plane_contracts`
- `core/execution_plane_kernel`
- `protocols/execution_plane_http`
- `protocols/execution_plane_jsonrpc`
- `placements/execution_plane_local`
- `runtimes/execution_plane_process`
- `conformance/execution_plane_testkit`

Reserved package homes for later waves are also tracked so topology and ownership stop drifting:

- `streaming/execution_plane_sse`
- `streaming/execution_plane_websocket`
- `placements/execution_plane_ssh`
- `placements/execution_plane_guest`
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

The Wave 1 repo gate for `execution_plane` is `ROOT_NO_STATIC_ANALYSIS` from
[`technical/12_repo_quality_gate_command_matrix.md`](technical/12_repo_quality_gate_command_matrix.md).

## License

MIT
