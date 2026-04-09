# ADR-003: Share Versioned Lineage And Route Contracts, Not One Mega Struct

## Decision

The stack shares:

- `AuthorityDecision.v1`
- `BoundarySessionDescriptor.v1`
- `ExecutionIntentEnvelope.v1`
- family-specific execution intents
- `ExecutionRoute.v1`
- `AttachGrant.v1`
- `CredentialHandleRef.v1`
- `ExecutionEvent.v1`
- `ExecutionOutcome.v1`

The stack does not force:

- one universal execution payload used identically by HTTP, CLI, service, JSON-RPC, and code-execution families

## Additional Rules

- all shared contracts are versioned
- all shared contracts define ownership and mutability rules
- execution events and execution outcomes stay distinct
- durable boundary/session descriptors stay distinct from lower runtime state
- failure classes are typed and shared

## Rationale

The architecture needs shared lineage and durable semantics without flattening every family into the same payload.

The important split is not "many structs versus one struct."

The important split is:

- durable truth versus raw execution facts
- portable core contracts versus family-specific projections
