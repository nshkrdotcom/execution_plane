# `runtimes/execution_plane_operator_terminal`

Owns the Execution Plane operator-terminal ingress family.

This package is intentionally separate from the root `execution_plane` Mix
package so base lower-runtime consumers do not inherit `ex_ratatui` unless
they explicitly opt into the operator-terminal lane.

## Responsibilities

- host operator-facing TUIs below product apps
- own local, SSH, and distributed operator-terminal surface semantics
- supervise operator-terminal registry and runtime children
- expose operator-terminal lifecycle and inspection APIs through
  `ExecutionPlane.OperatorTerminal`

## Non-Responsibilities

- workload process placement
- subprocess launch and PTY ownership for workload execution
- durable operator truth
- product-local rendering ownership

## Developer Workflow

```bash
cd runtimes/execution_plane_operator_terminal
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
```

## Related Reading

- [Execution Plane Workspace README](../../README.md)
- `technical/02_repo_topology_and_package_map.md` in the root `execution_plane`
  repo
- `technical/11_surface_exposure_and_contract_carriage_matrix.md` in the root
  `execution_plane` repo
