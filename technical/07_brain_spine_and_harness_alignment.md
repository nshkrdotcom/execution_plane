# Brain, Spine, And Harness Alignment

## `/home/home/p/g/n/citadel` (Brain)

After refactor:

- is the Brain
- authors `AuthorityDecision.v1`
- authors boundary, trust, approval, and topology direction
- owns `BoundaryIntent`, `TopologyIntent`, `InvocationRequest.V2`, `KernelSnapshot`, `SignalIngress`, `BoundaryLeaseTracker`
- bridges to `jido_integration` and `outer_brain`
- does not host lower runtime code
- does not own memory storage or proof-token ownership
- carries acceptable target-attestation classes in
  `ExecutionGovernance.v1.sandbox.acceptable_attestation`
- may provide an `ExecutionPlane.Authority.Verifier` implementation for node
  hosts, but does not become the node or a lane host

## `/home/home/p/g/n/jido_integration`

After refactor:

- stays Spine
- persists durable truth
- owns `BoundarySessionDescriptor.v1`
- owns route selection, replay, reconciliation, approvals, and callback truth
- projects Brain-authored intent into Execution Plane contracts
- does not own live execution mechanics
- maps governance projections into `ExecutionPlane.Admission.Request`
- owns fallback ladders by issuing separate
  runtime-client execute calls per acceptable-attestation rung when policy
  allows multiple target classes

## `jido_integration` Public Facade (`Jido.Integration.V2`)

After refactor:

- `jido_integration` exposes `Jido.Integration.V2` as the public facade
- may map or carry execution-plane contracts
- must not become the Execution Plane public API
- must not expose raw lower transport surfaces

## `/home/home/p/g/n/agent_session_manager`

After refactor:

- remains provider-neutral orchestration
- consumes durable descriptors and attach grants
- stays above family kits and below product UX
- must not reacquire transport ownership

## Cross-Repo Call Pattern

Authoritative async-first shape:

```
extravaganza (product intent)
  -> app_kit (product boundary enforcement)
    -> citadel (AuthorityDecision.v1)
    -> outer_brain (context pack, recall)
      -> mezzanine (pack lifecycle, Temporal dispatch)
        -> jido_integration (Spine durable truth, Jido.Integration.V2)
          -> ExecutionPlane.Runtime.Client
            -> execution_plane_node (admission, target verification, evidence)
              -> host-selected lane (process / HTTP / JSON-RPC / realtime)
              -> external world
                -> ExecutionEvent.v1, ExecutionOutcome.v1
                  -> jido_integration (durable meaning)
                    -> mezzanine (evidence, audit, promotion)
```

Synchronous convenience surfaces may exist above this core, but the durable architecture is async-first.

## Anti-Leak Rules

- `jido_integration` may carry or map contracts, but may not re-export the Execution Plane workspace as its public surface
- `jido_integration` may project intents, but may not host transport runtime code
- `jido_integration` may own fallback ladders, but each rung must be a
  separate runtime-client call; the node never silently downgrades inside one
  execution
- `agent_session_manager` may orchestrate session state, but may not parse provider protocols that belong in provider or family layers
- `outer_brain` must not own governed writes, access graph mutation, proof tokens, or policy storage
- `mezzanine` must not push raw semantic provider/model policy into lower execution layers
- `app_kit` and product code must not import lower stores directly

## Identity And Secret Rules

- Brain and Spine decide policy and secret references
- Execution Plane resolves credential handles close to execution
- raw long-lived secret propagation through intents is forbidden

## Durable Meaning Rule

- the Execution Plane emits raw facts
- the Spine persists and interprets durable meaning
- replay, callback truth, and approval truth remain Spine concerns even when lower execution is remote or long-lived
- node evidence is serializable execution evidence, not durable business truth
