# Brain, Spine, And Harness Alignment

## `/home/home/p/g/n/jido_os`

After refactor:

- stays Brain
- authors `AuthorityDecision.v1`
- authors boundary, trust, approval, and topology direction
- does not host lower runtime code

## `/home/home/p/g/n/jido_integration`

After refactor:

- stays Spine
- persists durable truth
- owns `BoundarySessionDescriptor.v1`
- owns route selection, replay, reconciliation, approvals, and callback truth
- projects Brain-authored intent into Execution Plane contracts
- does not own live execution mechanics

## `/home/home/p/g/n/jido_harness`

After refactor:

- remains a facade and IR package
- may map or carry execution-plane contracts
- must not become the Execution Plane public API

## `/home/home/p/g/n/agent_session_manager`

After refactor:

- remains provider-neutral orchestration
- consumes durable descriptors and attach grants
- stays above family kits and below product UX
- must not reacquire transport ownership

## Cross-Repo Call Pattern

Authoritative async-first shape:

`jido_os`
  -> `jido_integration`
  -> family kit or `jido_harness`
  -> Spine-authored execution contract
  -> `execution_plane`
  -> external world
  -> raw execution events and outcomes
  -> `jido_integration`

Synchronous convenience surfaces may exist above this core, but the durable architecture is async-first.

## Anti-Leak Rules

- `jido_harness` may carry or map contracts, but may not re-export the Execution Plane workspace as its public surface
- `jido_integration` may project intents, but may not host transport runtime code
- `agent_session_manager` may orchestrate session state, but may not parse provider protocols that belong in provider or family layers

## Identity And Secret Rules

- Brain and Spine decide policy and secret references
- Execution Plane resolves credential handles close to execution
- raw long-lived secret propagation through intents is forbidden

## Durable Meaning Rule

- the Execution Plane emits raw facts
- the Spine persists and interprets durable meaning
- replay, callback truth, and approval truth remain Spine concerns even when lower execution is remote or long-lived
