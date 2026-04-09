# ADR-001: Brain, Spine, And Execution Plane Are The Top-Level System Split

## Decision

The top-level system split is:

- Brain: `/home/home/p/g/n/jido_os`
- Spine: `/home/home/p/g/n/jido_integration`
- Execution Plane: `/home/home/p/g/n/execution_plane`

## Rationale

This is the clearest convergence from the source packets and the cleanest way to stop lower runtime mechanics from leaking into durable control-plane or reasoning repos.

The lower layer is not merely "hazardous code." It is a specific execution plane with explicit ownership of transport reality and raw execution facts.
