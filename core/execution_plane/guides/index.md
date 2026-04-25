# Execution Plane Guide

Execution Plane provides the shared lower-runtime layer used by higher-level
Elixir SDKs and family kits. It keeps execution contracts, placement
descriptors, target/admission values, evidence envelopes, codecs, and runtime
behaviours in one common substrate so product libraries can keep their own
semantic APIs.

## Published Surfaces

- `ExecutionPlane.Contracts`: versioned carried contract structs and
  normalizers
- `ExecutionPlane.Kernel`: route validation and pure dispatch planning
- `ExecutionPlane.Admission.Request`, `.Decision`, and `.Rejection`: node
  admission boundary values
- `ExecutionPlane.Authority.Ref` and `.Verifier`: opaque authority references
  and host-registered verification behaviour
- `ExecutionPlane.Sandbox.Profile` and `.AcceptableAttestation`: opaque
  policy carriage and target-selection inputs
- `ExecutionPlane.Target.Descriptor`, `.Attestation`, `.Verifier`, and
  `.Client`: verified target model and target protocol seam
- `ExecutionPlane.Runtime.Client` and `.NodeDescriptor`: governed runtime
  client boundary
- `ExecutionPlane.ExecutionRequest`, `.ExecutionResult`,
  `.ExecutionEvent`, `.Evidence`, and `.ExecutionRef`: serializable execution
  and evidence values
- `ExecutionPlane.Lane.Adapter` and `.Capabilities`: lane adapter contracts
- `ExecutionPlane.Placements`: local, SSH, and guest placement descriptors
- `ExecutionPlane.LowerSimulation`: lower-boundary simulation evidence helpers

## Package Homes

This checkout contains exactly eight Mix projects:

- `core/execution_plane` (`execution_plane`, the publishable common package)
- `protocols/execution_plane_http`
- `protocols/execution_plane_jsonrpc`
- `streaming/execution_plane_sse`
- `streaming/execution_plane_websocket`
- `runtimes/execution_plane_process`
- `runtimes/execution_plane_node`
- `runtimes/execution_plane_operator_terminal`

The repository root is a non-published `execution_plane_workspace` tooling
project. It owns Blitz workspace orchestration only.

The `core/execution_plane` package compiles these common source homes:

- `core/execution_plane_contracts`
- `core/execution_plane_kernel`
- `placements/execution_plane_local`
- `placements/execution_plane_ssh`
- `placements/execution_plane_guest`
- `conformance/execution_plane_testkit`

HTTP, JSON-RPC, SSE, WebSocket, process, node, and operator-terminal code live
in their package-local Mix projects. The former
`core/execution_plane_contracts`, `core/execution_plane_kernel`,
`placements/execution_plane_local`, `placements/execution_plane_ssh`,
`placements/execution_plane_guest`, and `conformance/execution_plane_testkit`
Mix roots are source homes only under `core/execution_plane`.

## Choosing The Right Layer

Use `execution_plane` directly when you are building a family kit or runtime
adapter that needs common lower contracts.

Use a lane package when your repo directly owns that lane:

- use `execution_plane_process` for local process/PTY/stdio execution
- use `execution_plane_http` for unary HTTP execution
- use `execution_plane_jsonrpc` for JSON-RPC framing and correlation
- use `execution_plane_sse` or `execution_plane_websocket` for lower realtime
  streams
- use `execution_plane_node` when you are hosting governed runtime admission
  over explicitly registered lanes and targets
- use `execution_plane_operator_terminal` for operator-facing terminal
  surfaces

Use a higher-level package when you need provider or product semantics:

- CLI SDKs normally consume `cli_subprocess_core`; downstream SDK users do not
  manually declare Execution Plane deps for ordinary CLI subprocess behavior.
- HTTP/provider SDKs keep their provider API above Pristine or another family
  kit.
- GraphQL/provider SDKs keep GraphQL semantics above Prismatic.
- Self-hosted inference SDKs keep model-server semantics above this
  package.

Standalone direct lane calls must carry direct lower-lane-owner provenance.
Governed calls must go through `ExecutionPlane.Runtime.Client` and a node host
that validates authority, acceptable attestation, target descriptors, and lane
availability.

The node never performs an internal fallback ladder. If a Brain or Spine policy
allows multiple attestation classes, that owner issues separate runtime-client
calls and records each rejection or success.

`local-erlexec-weak` is an honest weak local process attestation. It is not a
sandbox claim.

## Quality Gate

```bash
mix ci
```

From the repository root, this gate uses Blitz to run every package-local
`mix ci`. From a package directory, it runs that package's formatting checks,
compile warnings-as-errors, tests, Credo, Dialyzer, and docs with warnings
treated as errors.
