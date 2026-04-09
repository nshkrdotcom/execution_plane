# ADR-012: No Compatibility-Shim-First Architecture Or Intermediate Public APIs

## Decision

The implementation target is the final architecture directly.

Do not:

- add transitional public APIs as the long-term target
- preserve duplicate runtime owners after a capability wave closes
- keep `/home/home/p/g/n/external_runtime_transport` as an active architecture owner once its covered capabilities have moved

Before broad adoption begins, freeze:

- the contract packet
- package topology
- public-surface rules
- Brain-to-Spine and Spine-to-Execution invariants

Retirement happens in the wave that first covers the capability slice, not in a later global cleanup wave.

## Clarification

Capability waves are allowed.

What is not allowed is a compatibility architecture that pretends both old and new owners are first-class for the same completed capability.

## Rationale

The system needs an execution method safer than one heroic rewrite, but it still cannot afford to preserve the old ownership graph as the new normal.
