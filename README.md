# Execution Plane Workspace

<p align="center">
  <img src="assets/execution_plane.svg" width="200" height="200" alt="Execution Plane logo">
</p>

This repository is a non-umbrella Mix workspace. The repository root is a
tooling project only; it is not the `execution_plane` Hex package.

The publishable common substrate package lives at `core/execution_plane`.
Blitz and workspace orchestration live only in the root project so they cannot
enter the published `execution_plane` package dependency graph.

## Mix Projects

The checkout contains exactly eight active Mix projects:

- `core/execution_plane`: publishable `execution_plane` common substrate
- `protocols/execution_plane_http`: unary HTTP lane
- `protocols/execution_plane_jsonrpc`: JSON-RPC framing and correlation lane
- `streaming/execution_plane_sse`: SSE framing and stream lifecycle lane
- `streaming/execution_plane_websocket`: WebSocket handshake/frame lane
- `runtimes/execution_plane_process`: process/PTY/stdio lane, the sole owner
  of `erlexec`
- `runtimes/execution_plane_node`: lane-neutral runtime node and local
  `ExecutionPlane.Runtime.Client`
- `runtimes/execution_plane_operator_terminal`: operator-facing terminal
  runtime, kept separate so base consumers do not inherit `ex_ratatui`

The root `mix.exs` is `:execution_plane_workspace`; it exists to run Blitz
workspace tasks, root documentation, and repository-level checks.

## Installing Packages

Add the common substrate package when you need contracts, codecs, placement
descriptors, runtime-client behaviours, evidence envelopes, and pure helpers:

```elixir
def deps do
  [
    {:execution_plane, "~> 0.1.0"}
  ]
end
```

Lane hosts and family kits opt into the exact lane packages they run:

```elixir
def deps do
  [
    {:execution_plane, "~> 0.1.0"},
    {:execution_plane_node, "~> 0.1.0"},
    {:execution_plane_process, "~> 0.1.0"}
  ]
end
```

Downstream SDK users normally should not add Execution Plane deps manually.
For example, CLI provider SDKs get local subprocess execution transitively
through `cli_subprocess_core`, and REST/GraphQL-only SDKs should stay above
their HTTP or GraphQL family kit.

## Development

Run the workspace gate from the repository root:

```bash
mix deps.get
mix ci
```

The root gate uses Blitz to run package-local `mix ci` aliases for every
active package. Package gates can still be run directly:

```bash
cd core/execution_plane && mix ci
cd protocols/execution_plane_http && mix ci
cd protocols/execution_plane_jsonrpc && mix ci
cd streaming/execution_plane_sse && mix ci
cd streaming/execution_plane_websocket && mix ci
cd runtimes/execution_plane_process && mix ci
cd runtimes/execution_plane_node && mix ci
cd runtimes/execution_plane_operator_terminal && mix ci
```

## Publishing

Publish from package directories, never from the repository root:

```bash
cd core/execution_plane
mix hex.build
mix hex.publish
```

Publish the common `execution_plane` package first, then lane packages that
depend on it, then `execution_plane_node`, and finally
`execution_plane_operator_terminal`.

## Sandbox And Target Honesty

The common contracts carry `ExecutionPlane.Sandbox.Profile` and
`ExecutionPlane.Sandbox.AcceptableAttestation` values as opaque policy and
target-selection data. They do not enforce a sandbox by themselves.

`local-erlexec-weak` means local process execution with weak local
attestation. It is not a container, microVM, or cryptographic isolation claim.
Stronger target classes must be backed by a host-owned verifier and target
protocol evidence before they enter the node routing table.

## License

MIT
