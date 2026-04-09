# Surface Exposure And Contract Carriage Matrix

## Purpose

The architecture needs a hard rule for where contracts may live, where they may be carried, and which repo is allowed to expose which public surface.

Without that rule, the Execution Plane will leak upward and the family kits or facades will become thin aliases.

## Exposure Matrix

| Repo / package | Public stable surface | May carry Execution Plane contracts? | Must not expose |
| --- | --- | --- | --- |
| `execution_plane/core/execution_plane_contracts` | typed lower-boundary contracts and validators | yes, owner | higher-level family semantics |
| `execution_plane/core/execution_plane_kernel` | internal kernel APIs only | yes | public product-facing runtime API |
| `execution_plane/protocols/*` | internal lower execution primitives | yes | semantic HTTP, GraphQL, provider, or service APIs |
| `pristine` | semantic HTTP runtime | yes, mapped | raw `execution_plane_http` package surface |
| `prismatic` | semantic GraphQL runtime | yes, mapped | raw lower HTTP transport surface |
| `reqllm_next` | provider and realtime semantics | yes, mapped | repo-local transport ownership reborn under a new name |
| `cli_subprocess_core` | CLI family planning and session semantics | yes, mapped | raw process transport primitives as public API |
| `codex_sdk` | Codex-native semantics | yes, mapped | raw Execution Plane package names |
| `claude_agent_sdk` | Claude-native control semantics | yes, mapped | raw Execution Plane package names |
| `gemini_cli_sdk` | Gemini-specific CLI semantics | yes, mapped | raw Execution Plane package names |
| `amp_sdk` | Amp-specific CLI semantics | yes, mapped | raw Execution Plane package names |
| `self_hosted_inference_core` | service-runtime semantics | yes, mapped | raw process runtime primitives as public API |
| `llama_cpp_sdk` | backend semantics | yes, mapped | lower service runtime mechanics |
| `agent_session_manager` | provider-neutral session orchestration | yes, mapped | transport or provider protocol internals |
| `jido_harness` | public runtime-driver and facade IR | yes, mapped | wholesale re-export of `execution_plane` |
| `jido_integration` | durable control-plane and boundary APIs | yes, carried | live transport or runtime implementation |
| `jido_os` | authority and policy APIs | yes, carried indirectly | lower execution mechanics |

## Contract Carriage Rules

- `execution_plane_contracts` owns the canonical structs, validators, enums, and fixtures
- `jido_integration`, `jido_harness`, and `agent_session_manager` may carry those contracts
- family kits may emit or consume mapped forms of those contracts
- provider SDKs consume family-kit surfaces or mapped contract projections, not raw Execution Plane packages
- if downstream adoption exposes an upstream surface or contract defect, fixing that upstream repo is part of closing the active wave

## Sandbox And Session Management Surface Rules

- placement, network, filesystem, credential, and approval policy remain distinct concepts even when a single public API hides some complexity
- attach/reconnect surfaces must map to `BoundarySessionDescriptor.v1`, `AttachGrant.v1`, `ExecutionEvent.v1`, and `ExecutionOutcome.v1` without redefining their ownership
- public session-management APIs must reveal durable meaning and operator-safe semantics, not raw transport internals

## Review Rule

Before closing any implementation wave, check:

- the intended public surface exists in the right repo
- the lower package is not being re-exported as the product surface
- mapped contract shapes do not alter the ownership semantics of the canonical contracts
- any upstream defect exposed by downstream adoption was fixed in the same wave or explicitly blocked before closure
