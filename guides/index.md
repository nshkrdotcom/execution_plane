# Execution Plane Guide

Execution Plane provides the shared lower-runtime layer used by higher-level
Elixir SDKs and family kits. It keeps execution contracts, placement
descriptors, and runtime helpers in one package so product libraries can keep
their own semantic APIs.

## Published Surfaces

- `ExecutionPlane.Contracts`: versioned contract structs and normalizers
- `ExecutionPlane.Kernel`: route validation and dispatch planning
- `ExecutionPlane.HTTP`: unary HTTP execution
- `ExecutionPlane.Process`: one-shot local process execution
- `ExecutionPlane.Process.Transport`: long-lived process transport
- `ExecutionPlane.JsonRpc`: unary JSON-RPC execution over process transport
- `ExecutionPlane.Placements`: local, SSH, and guest placement descriptors
- `ExecutionPlane.LowerSimulation`: lower-boundary simulation evidence helpers

## Package Homes

The root package publishes the active source homes it compiles:

- `core/execution_plane_contracts`
- `core/execution_plane_kernel`
- `protocols/execution_plane_http`
- `protocols/execution_plane_jsonrpc`
- `streaming/execution_plane_sse`
- `streaming/execution_plane_websocket`
- `placements/execution_plane_local`
- `placements/execution_plane_ssh`
- `placements/execution_plane_guest`
- `runtimes/execution_plane_process`
- `conformance/execution_plane_testkit`

The terminal UI runtime is published separately as
`execution_plane_operator_terminal`.

## Choosing The Right Layer

Use `execution_plane` directly when you are building a family kit or runtime
adapter that needs lower execution contracts.

Use a higher-level package when you need provider or product semantics:

- CLI SDKs should normally consume `cli_subprocess_core`.
- HTTP/provider SDKs should keep their provider API above this package.
- Self-hosted inference SDKs should keep model-server semantics above this
  package.

## Quality Gate

```bash
mix ci
```

The gate runs formatting checks, compile warnings-as-errors, tests, Credo,
Dialyzer, and docs with warnings treated as errors.
