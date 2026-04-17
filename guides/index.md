# Guide Index

Execution Plane is the lower runtime workspace in the Brain / Spine /
Execution Plane architecture. Wave 1 freezes the packet and topology; Waves 2,
3, 6, and 7 land the executable lower substrate, the first proven family-kit
lanes, long-lived process transport, and truthful placement breadth on those
frozen contracts.

## Recommended Reading Order

1. [`README.md`](../README.md)
2. [`technical/01_north_star_architecture.md`](../technical/01_north_star_architecture.md)
3. [`technical/02_repo_topology_and_package_map.md`](../technical/02_repo_topology_and_package_map.md)
4. [`technical/03_shared_contracts_and_lineage.md`](../technical/03_shared_contracts_and_lineage.md)
5. [`technical/04_http_graphql_and_realtime_family_design.md`](../technical/04_http_graphql_and_realtime_family_design.md)
6. [`technical/05_process_and_agent_session_family_design.md`](../technical/05_process_and_agent_session_family_design.md)
7. [`technical/07_brain_spine_and_harness_alignment.md`](../technical/07_brain_spine_and_harness_alignment.md)
8. [`JIDO_BRAIN_CONTRACT_CONTEXT/README.md`](../JIDO_BRAIN_CONTRACT_CONTEXT/README.md)
9. [`technical/10_subset_complete_big_bang_execution_model.md`](../technical/10_subset_complete_big_bang_execution_model.md)
10. [`technical/11_surface_exposure_and_contract_carriage_matrix.md`](../technical/11_surface_exposure_and_contract_carriage_matrix.md)
11. [`technical/12_repo_quality_gate_command_matrix.md`](../technical/12_repo_quality_gate_command_matrix.md)
12. [`adrs/ADR-012-no-staged-compatibility-shims-or-intermediate-public-apis.md`](../adrs/ADR-012-no-staged-compatibility-shims-or-intermediate-public-apis.md)
13. [`adrs/ADR-015-public-surfaces-expose-mapped-family-and-facade-irs-not-raw-execution-plane-packages.md`](../adrs/ADR-015-public-surfaces-expose-mapped-family-and-facade-irs-not-raw-execution-plane-packages.md)
14. [`adrs/ADR-016-upstream-fixes-are-allowed-within-the-active-wave.md`](../adrs/ADR-016-upstream-fixes-are-allowed-within-the-active-wave.md)

## Closed Runtime Outcomes

The closed substrate, session, and placement-breadth waves leave the repo with:

- a working execution-plane kernel on the final contracts
- the migrated narrow placement seam
- attachable long-lived process sessions on the same lower substrate
- local, SSH, and guest placement helpers below higher family kits
- unary HTTP, basic process, and minimal unary JSON-RPC execution
- frozen helper surfaces for downstream unary HTTP, one-shot process, and unary JSON-RPC adoption
- minimal-lane contract corrections exposed by real downstream prove-out
- raw execution fact emission and terminal outcomes
- conformance coverage for the lower substrate slice
- honest isolation docs that distinguish transport placement from stronger sandbox backends

It still must not:

- invent alternate ownership semantics
- expose raw lower packages as product APIs in higher repos
- preserve `external_runtime_transport` as an active owner for the covered slice

## Package Homes

Minimal first-cut package homes:

- [`core/execution_plane_contracts`](../core/execution_plane_contracts/README.md)
- [`core/execution_plane_kernel`](../core/execution_plane_kernel/README.md)
- [`protocols/execution_plane_http`](../protocols/execution_plane_http/README.md)
- [`protocols/execution_plane_jsonrpc`](../protocols/execution_plane_jsonrpc/README.md)
- [`placements/execution_plane_local`](../placements/execution_plane_local/README.md)
- [`placements/execution_plane_ssh`](../placements/execution_plane_ssh/README.md)
- [`placements/execution_plane_guest`](../placements/execution_plane_guest/README.md)
- [`runtimes/execution_plane_process`](../runtimes/execution_plane_process/README.md)
- [`conformance/execution_plane_testkit`](../conformance/execution_plane_testkit/README.md)

Reserved future package homes:

- [`streaming/execution_plane_sse`](../streaming/execution_plane_sse/README.md)
- [`streaming/execution_plane_websocket`](../streaming/execution_plane_websocket/README.md)
- [`sandboxes/execution_plane_container`](../sandboxes/execution_plane_container/README.md)
- [`sandboxes/execution_plane_microvm`](../sandboxes/execution_plane_microvm/README.md)
