# ADR-009: ASM Remains The Agent Session Kernel And `jido_harness` Remains A Facade

## Decision

- `/home/home/p/g/n/agent_session_manager` remains the agent session kernel
- `/home/home/p/g/n/jido_harness` remains the public runtime-driver and contract facade

Neither repo becomes the Execution Plane.

## Additional Rules

- ASM consumes durable descriptors, routes, and attach grants without owning transport families
- `jido_harness` may map lower contracts into public driver IR, but may not re-export raw Execution Plane packages wholesale

## Rationale

Both repos are already closer to the correct role than the incorrect one, as long as `jido_harness` maps lower contracts instead of exposing the lower repo wholesale.
