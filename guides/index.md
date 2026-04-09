# Guide Index

Execution Plane is the lower runtime workspace in the Brain / Spine /
Execution Plane architecture. Wave 1 is intentionally about contract and
surface freeze, not broad runtime extraction.

## Recommended Reading Order

1. [`README.md`](../README.md)
2. [`technical/01_north_star_architecture.md`](../technical/01_north_star_architecture.md)
3. [`technical/02_repo_topology_and_package_map.md`](../technical/02_repo_topology_and_package_map.md)
4. [`technical/03_shared_contracts_and_lineage.md`](../technical/03_shared_contracts_and_lineage.md)
5. [`technical/07_brain_spine_and_harness_alignment.md`](../technical/07_brain_spine_and_harness_alignment.md)
6. [`JIDO_BRAIN_CONTRACT_CONTEXT/README.md`](../JIDO_BRAIN_CONTRACT_CONTEXT/README.md)
7. [`technical/10_subset_complete_big_bang_execution_model.md`](../technical/10_subset_complete_big_bang_execution_model.md)
8. [`technical/11_surface_exposure_and_contract_carriage_matrix.md`](../technical/11_surface_exposure_and_contract_carriage_matrix.md)
9. [`technical/12_repo_quality_gate_command_matrix.md`](../technical/12_repo_quality_gate_command_matrix.md)
10. the Wave 1 checklist and prompt:
    [`prompts/01_contract_packet_and_execution_plane_foundation_checklist.md`](../prompts/01_contract_packet_and_execution_plane_foundation_checklist.md)
    and
    [`prompts/01_contract_packet_and_execution_plane_foundation_implementation_prompt.md`](../prompts/01_contract_packet_and_execution_plane_foundation_implementation_prompt.md)

## Wave 1 Outcomes

Wave 1 must leave the repo with:

- tracked workspace package homes
- the normative packet docs in-repo
- versioned contract modules and failure taxonomy scaffolding
- lineage continuity fixtures and tests
- professional docs menus

It must not:

- start broad lower-runtime extraction ahead of the freeze
- invent alternate ownership semantics
- expose raw lower packages as product APIs in higher repos

## Package Homes

Minimal first-cut package homes:

- [`core/execution_plane_contracts`](../core/execution_plane_contracts/README.md)
- [`core/execution_plane_kernel`](../core/execution_plane_kernel/README.md)
- [`protocols/execution_plane_http`](../protocols/execution_plane_http/README.md)
- [`protocols/execution_plane_jsonrpc`](../protocols/execution_plane_jsonrpc/README.md)
- [`placements/execution_plane_local`](../placements/execution_plane_local/README.md)
- [`runtimes/execution_plane_process`](../runtimes/execution_plane_process/README.md)
- [`conformance/execution_plane_testkit`](../conformance/execution_plane_testkit/README.md)

Reserved future package homes:

- [`streaming/execution_plane_sse`](../streaming/execution_plane_sse/README.md)
- [`streaming/execution_plane_websocket`](../streaming/execution_plane_websocket/README.md)
- [`placements/execution_plane_ssh`](../placements/execution_plane_ssh/README.md)
- [`placements/execution_plane_guest`](../placements/execution_plane_guest/README.md)
- [`sandboxes/execution_plane_container`](../sandboxes/execution_plane_container/README.md)
- [`sandboxes/execution_plane_microvm`](../sandboxes/execution_plane_microvm/README.md)
