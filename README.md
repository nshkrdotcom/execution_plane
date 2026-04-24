# Execution Plane

<p align="center">
  <img src="assets/execution_plane.svg" width="200" height="200" alt="Execution Plane logo">
</p>

<p align="center">
  <a href="https://github.com/nshkrdotcom/execution_plane"><img alt="GitHub" src="https://img.shields.io/badge/github-nshkrdotcom%2Fexecution_plane-24292f?logo=github"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
</p>

Execution Plane is a lower-runtime substrate for Elixir systems that need
shared execution contracts, route planning, local process execution, HTTP
execution, JSON-RPC request handling, placement descriptors, and conformance
fixtures without each higher-level SDK re-owning those mechanics.

It is designed to sit below family kits such as CLI subprocess, HTTP/provider,
GraphQL/provider, and self-hosted inference libraries. Product SDKs should
usually depend on those family kits rather than calling Execution Plane
directly.

## Installation

Add `execution_plane` to your dependencies:

```elixir
def deps do
  [
    {:execution_plane, "~> 0.1.0"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## What It Provides

- Versioned execution contracts under `ExecutionPlane.Contracts`
- Route validation and dispatch planning through `ExecutionPlane.Kernel`
- One-shot local command execution through `ExecutionPlane.Process`
- Long-lived process transport under `ExecutionPlane.Process.Transport`
- Unary HTTP execution through `ExecutionPlane.HTTP`
- Unary JSON-RPC execution through `ExecutionPlane.JsonRpc`
- Local, SSH, and guest placement descriptors under `ExecutionPlane.Placements`
- Lower-runtime simulation and conformance helpers for downstream packages

The operator-terminal UI runtime is published separately as
`execution_plane_operator_terminal`; depending on `execution_plane` alone does
not pull in terminal UI dependencies.

## Process Execution

Run a local command through the covered one-shot process lane:

```elixir
{:ok, result} =
  ExecutionPlane.Process.run(%{
    command: "printf",
    argv: ["hello\\n"],
    timeout_ms: 1_000
  })

result.status
```

Use `ExecutionPlane.Process.Transport` when you need a long-lived process
session with attachable stdin/stdout event handling.

## HTTP Execution

Execute a unary HTTP request through the shared lower-runtime contract path:

```elixir
{:ok, result} =
  ExecutionPlane.HTTP.unary(%{
    method: "GET",
    url: "https://example.com",
    headers: [{"accept", "text/html"}],
    timeout_ms: 5_000
  })

result.status
```

Higher-level HTTP SDKs can use this surface while keeping their provider
semantics in their own packages.

## JSON-RPC Execution

Execute a unary JSON-RPC request over a process transport:

```elixir
{:ok, result} =
  ExecutionPlane.JsonRpc.call(%{
    command: "node",
    argv: ["server.js"],
    request: %{"jsonrpc" => "2.0", "id" => 1, "method" => "ping"},
    timeout_ms: 2_000
  })

result.status
```

## Placement Surfaces

Execution Plane includes placement descriptors for local, SSH, and guest-backed
execution surfaces. They describe where execution is allowed to happen; they do
not turn a placement into a stronger sandbox guarantee by themselves.

## Development

```bash
mix deps.get
mix format
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
```

The repository gate is:

```bash
mix ci
```

## License

MIT
