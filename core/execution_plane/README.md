# Execution Plane Package

<p align="center">
  <img src="assets/execution_plane.svg" width="200" height="200" alt="Execution Plane logo">
</p>

<p align="center">
  <a href="https://github.com/nshkrdotcom/execution_plane"><img alt="GitHub" src="https://img.shields.io/badge/github-nshkrdotcom%2Fexecution_plane-24292f?logo=github"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
</p>

Execution Plane is a lower-runtime substrate for Elixir systems that need
shared execution contracts, admission values, target descriptors, lane
adapter behaviours, placement descriptors, codecs, evidence envelopes, and
conformance fixtures without each higher-level SDK re-owning those mechanics.

It is designed to sit below family kits such as CLI subprocess, HTTP/provider,
GraphQL/provider, and self-hosted inference libraries. Product SDKs should
usually depend on those family kits rather than calling Execution Plane
directly.

## Installation

Add this package when you need the common substrate only:

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

Then fetch dependencies:

```bash
mix deps.get
```

Downstream SDK users normally should not add Execution Plane deps manually.
For example, CLI provider SDKs get local subprocess execution transitively
through `cli_subprocess_core`, and REST/GraphQL-only SDKs should stay above
their HTTP or GraphQL family kit.

## What It Provides

- Root common contracts under `ExecutionPlane.Contracts`
- Root boundary contracts for admission, authority references, sandbox
  profile carriage, acceptable attestation classes, target descriptors,
  runtime clients, execution requests, execution results, events, evidence,
  provenance, and lane adapters
- JSON codecs for all remote-boundary values
- Placement descriptors under `ExecutionPlane.Placements`
- Route validation, pure dispatch planning, and lower simulation helpers
- Testkit fixtures for downstream conformance

The package is intentionally lane-light. It does not depend on `erlexec`,
`finch`, `mint_web_socket`, `server_sent_events`, or `ex_ratatui`.

## Repository Position

This is the publishable `execution_plane` package under the repository
workspace at `core/execution_plane`. The repository root is a non-published
Blitz workspace project and must not be used as the Hex package destination.

The former child roots `core/execution_plane_contracts`,
`core/execution_plane_kernel`, `placements/execution_plane_local`,
`placements/execution_plane_ssh`, `placements/execution_plane_guest`, and
`conformance/execution_plane_testkit` are source homes compiled by this
package; they are not separate Mix projects.

## Execution Modes

Standalone lane owners may call their lane package directly and must mark the
request provenance as `direct_lower_lane_owner`. This is honest local
execution, not Citadel or node admission.

Governed callers should go through `ExecutionPlane.Runtime.Client`. A node host
starts `execution_plane_node`, declares the lane packages it is willing to
run, registers lane adapters, target verifiers, evidence sinks, and an
authority verifier, then calls `complete_registration/2` before admitting
traffic.

The node validates:

- contract version
- authority reference through the registered authority verifier
- placement and runtime constraints carried in the admission request
- target attestation through registered target verifiers
- lane availability through explicit lane registration
- `acceptable_attestation` intersection against verified targets

One node execute call dispatches to at most one verified target. Fallback
ladders belong above the node, where an owner can issue separate
runtime-client execute calls and record each rejection or success.

## Sandbox And Target Honesty

The root contracts carry `ExecutionPlane.Sandbox.Profile` and
`ExecutionPlane.Sandbox.AcceptableAttestation` values as opaque policy and
target-selection data. They do not enforce a sandbox by themselves.

`local-erlexec-weak` means local process execution with weak local
attestation. It is not a container, microVM, or cryptographic isolation claim.
Stronger target classes must be backed by a host-owned verifier and target
protocol evidence before they enter the node routing table.

## Publish Order

Publish this `execution_plane` package first, then lane packages that
depend on it, then `execution_plane_node`, and finally
`execution_plane_operator_terminal`. Repos such as Citadel and JidoIntegration
that carry or map Execution Plane values should publish after the root
contract package is available.

Local workspace development may use sibling path dependencies. Published
artifacts must not silently depend on this workstation layout.

## Development

The package gate is:

```bash
mix ci
```

Run the full repository gate from the workspace root with `mix ci`; that root
gate uses Blitz and is not part of this package's published dependency graph.

## License

MIT
