# ADR-009: ASM Remains The Agent Session Kernel And `jido_integration` Remains A Facade

## Decision

- `/home/home/p/g/n/agent_session_manager` remains the agent session kernel
- `/home/home/p/g/n/jido_integration` serves the public runtime-driver and contract facade via `Jido.Integration.V2`

Neither repo becomes the Execution Plane.

## Additional Rules

- ASM consumes durable descriptors, routes, and attach grants without owning transport families
- `jido_integration` may map lower contracts into public driver IR, but may not re-export raw Execution Plane packages wholesale

## Rationale

ASM remains the provider-neutral session orchestration layer above family kits. `jido_integration` serves as the public facade for contract mapping without becoming a thin alias for lower runtime mechanics.

## Scope Update (2026-04-24)

`agent_session_manager` retains its provider-neutral session orchestration role above family kits.

`jido_integration` directly serves the public facade role and must not expose raw lower transport surfaces as its public API.
