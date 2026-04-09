# Execution Plane

<p align="center">
  <img src="assets/execution_plane.svg" width="200" height="200" alt="Execution Plane logo">
</p>

Execution Plane is an Elixir/OTP runtime substrate for boundary-aware AI infrastructure. The project is intended to be the lower execution layer for process execution, protocol framing, transport lifecycle, realtime streams, JSON-RPC control lanes, and future sandbox-backed placement under one composable kernel.

## Status

This repository is starting as a public scaffold:

- package metadata is in place for Hex and HexDocs
- the base OTP application exists
- the architecture direction is established

The next step is building out the lower execution-plane packages and contracts that sit under higher semantic runtimes.

## Planned Scope

- shared execution-plane contracts
- lower HTTP, SSE, WebSocket, and JSON-RPC protocol machinery
- process execution and attach/reconnect mechanics
- placement drivers for local, SSH, and guest-backed execution
- future stronger sandbox adapters
- conformance tooling for cross-surface behavior

## Development

```bash
mix deps.get
mix test
```

## Installation

Once published, the package can be installed by adding `execution_plane` to your dependencies:

```elixir
def deps do
  [
    {:execution_plane, "~> 0.1.0"}
  ]
end
```

## Documentation

HexDocs configuration includes the repository logo at [`assets/execution_plane.svg`](assets/execution_plane.svg). Once published, the docs will live at <https://hexdocs.pm/execution_plane>.

## License

MIT
