# Execution Plane HTTP

<p align="center">
  <img src="assets/execution_plane_http.svg" width="200" height="200" alt="Execution Plane HTTP logo">
</p>

<p align="center">
  <a href="https://github.com/nshkrdotcom/execution_plane"><img alt="GitHub" src="https://img.shields.io/badge/github-nshkrdotcom%2Fexecution_plane-24292f?logo=github"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
</p>

`execution_plane_http` owns the lower unary HTTP lane and lane-adapter
boundary for request/response execution. Version 0.2.0 adds a cancelable unary
session lifecycle backed by Erlang/OTP `:httpc` asynchronous request IDs and
`:httpc.cancel_request/1`.

## Installation

```elixir
def deps do
  [
    {:execution_plane_http, "~> 0.2.0"}
  ]
end
```

All commands default to the published `execution_plane ~> 0.3.0` core package.
Workspace development can select a local source through the standard
`MIX_WORKSPACE_OPS_BOOTSTRAP` hook. No registry tooling is required.

## Unary execution

Existing callers can continue using the synchronous helper:

```elixir
{:ok, result} =
  ExecutionPlane.HTTP.unary(
    %{url: "https://example.com/status", method: "GET"},
    lineage: %{idempotency_key: "status-check"}
  )
```

Cancelable callers use the same kernel path through a lightweight session:

```elixir
{:ok, session} =
  ExecutionPlane.HTTP.start_unary(
    %{url: "https://example.com/status", method: "GET"},
    lineage: %{idempotency_key: "status-check"}
  )

:ok = ExecutionPlane.HTTP.cancel_unary(session, :caller_cancelled)
{:error, result} = ExecutionPlane.HTTP.await_unary(session, 5_000)
```

The process that starts a session owns its terminal result and must call
`await_unary/2`. `cancel_unary/2` may be called from another BEAM process. A
successful cancellation acknowledgment means the request-owning process called
`:httpc.cancel_request/1`; it does **not** prove that a remote service never
received or began processing a request, and it cannot roll back a remote side
effect. Because `:httpc` completion and cancellation are asynchronous, a normal
response that already won the local race may still be the terminal result.

Cancellation reasons are lifecycle-control data only. They are not copied into
the lower execution outcome or raw payload.

## Guides

The HexDocs menu includes the guide index, installation notes, usage notes,
and publishing checklist for this package.
