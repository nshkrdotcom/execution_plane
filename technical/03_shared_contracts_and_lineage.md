# Shared Contracts And Lineage

## Principle

Share lineage, route, event, and outcome contracts.

Do not force every family to share one giant universal runtime struct.

The Spine-to-Execution boundary must be explicit, versioned, replayable, ownership-safe, and narrow enough that semantic families can stay semantic.

## Contract Rules

Every cross-layer contract must define:

- `contract_version`
- stable lineage identifiers
- idempotency semantics
- ownership and mutability rules
- validation invariants
- replay/reconciliation behavior
- extension rules

Portable core fields stay small and versioned. Family-specific or vendor-specific additions live in explicit `extensions` maps rather than mutating the portable core.

## Versioning Rules

- `v1` contracts are the first stable wire and storage shape.
- additive optional fields within a major version are allowed only when validation and ownership rules remain unchanged
- breaking field semantics require a new contract major version
- producers must emit the major version they implement
- consumers must reject unknown required major versions cleanly
- extension maps may carry experimental fields, but extension keys must be namespaced and must not redefine core semantics

## Canonical Lineage Keys

The packet standardizes the following identifiers:

- `tenant_id`
- `request_id`
- `decision_id`
- `boundary_session_id`
- `attempt_ref`
- `route_id`
- `event_id`
- `idempotency_key`

The same semantic request must keep the same `idempotency_key` across retries within a boundary session.

## Canonical Contract Stack

### `AuthorityDecision.v1`

Direction:

- Brain -> Spine

Owner:

- `/home/home/p/g/n/citadel` (Brain; authority compilation and policy direction)

Carrier and durable persistence owner:

- `/home/home/p/g/n/jido_integration`

Core fields:

- `contract_version`
- `decision_id`
- `tenant_id`
- `request_id`
- `policy_version`
- `boundary_class`
- `trust_profile`
- `approval_profile`
- `egress_profile`
- `workspace_profile`
- `resource_profile`
- `decision_hash`
- `extensions`

### `BoundarySessionDescriptor.v1`

Direction:

- Spine durable truth

Owner:

- `/home/home/p/g/n/jido_integration`

Purpose:

- durable boundary/session descriptor
- attachability and checkpointing state
- workspace and artifact refs
- policy echo and extensions
- lease and approval references

Core fields:

- `contract_version`
- `boundary_session_id`
- `decision_id`
- `session_status`
- `attach_state`
- `workspace_ref`
- `artifact_refs`
- `lease_refs`
- `approval_refs`
- `policy_echo`
- `extensions`

### `ExecutionIntentEnvelope.v1`

Direction:

- Spine -> Execution Plane

Purpose:

- one family-neutral envelope carrying lineage, policy refs, route template refs, credential handles, timeout metadata, and cancellation metadata

Core fields:

- `contract_version`
- `intent_id`
- `family`
- `protocol`
- `idempotency_key`
- `boundary_session_id`
- `decision_id`
- `lease_ref`
- `route_template_ref`
- `credential_handle_refs`
- `attempt_ref`
- `deadline_at`
- `cancellation_ref`
- `requested_capabilities`
- `extensions`

### `HttpExecutionIntent.v1`

Used by:

- `/home/home/p/g/n/pristine`
- `/home/home/p/g/n/prismatic`
- `/home/home/p/g/n/reqllm_next`

Core fields:

- `envelope`
- `request_shape`
- `stream_mode`
- `headers`
- `body`
- `egress_surface`
- `timeouts`
- `retry_class`

### `ProcessExecutionIntent.v1`

Used by:

- `/home/home/p/g/n/cli_subprocess_core`
- `/home/home/p/g/n/self_hosted_inference_core`
- process-backed control lanes

Core fields:

- `envelope`
- `command`
- `argv`
- `env_projection`
- `cwd`
- `stdio_mode`
- `execution_surface`
- `shutdown_policy`

### `JsonRpcExecutionIntent.v1`

Used by:

- `/home/home/p/g/n/codex_sdk`
- provider CLI control planes

Core fields:

- `envelope`
- `transport_binding`
- `protocol_schema`
- `request`
- `session_policy`

### `ExecutionRoute.v1`

Direction:

- Spine durable route choice and Execution Plane route resolution

Core fields:

- `contract_version`
- `route_id`
- `family`
- `protocol`
- `transport_family`
- `placement_family`
- `resolved_target`
- `resolved_budget`
- `lineage`

### `ExecutionPlane.AttachGrant.v1`

Direction:

- governed grant issuer -> Execution Plane and Mezzanine activity surfaces

Core fields:

- `contract_version`
- `tenant_ref`
- `installation_ref`
- `workspace_ref`
- `project_ref`
- `environment_ref`
- `principal_ref` or `system_actor_ref`
- `resource_ref`
- `authority_packet_ref`
- `permission_decision_ref`
- `idempotency_key`
- `trace_id`
- `correlation_id`
- `release_manifest_ref`
- `attach_grant_ref`
- `lease_ref`
- `hazmat_resource_ref`
- `grant_scope`
- `expires_at`
- `revocation_ref`

The legacy narrow `attach_grant.v1` shape is not accepted by the Phase 4
contract packet.

### `ExecutionPlane.StreamBackpressure.v1`

Purpose:

- records budget pressure, deterministic stream termination reason, heartbeat
  evidence, and diagnostics refs.

Core fields:

- `contract_version`
- tenant, installation, workspace, project, environment, actor, resource,
  authority, permission decision, idempotency, trace, correlation, and release
  manifest refs
- `stream_ref`
- `budget_ref`
- `pressure_class`
- `termination_reason`
- `last_heartbeat_at`
- `diagnostics_ref`

### `ExecutionPlane.WorkerBudget.v1`

Purpose:

- records worker admission or pressure-shedding evidence without allowing
  budget bypass.

Core fields:

- `contract_version`
- tenant, installation, workspace, project, environment, actor, resource,
  authority, permission decision, idempotency, trace, correlation, and release
  manifest refs
- `worker_pool_ref`
- `budget_ref`
- `queue_ref`
- `current_load`
- `admission_decision_ref`
- `shed_reason`

### `ExecutionPlane.NoBypassScan.v1`

Purpose:

- records source-boundary proof that public/product/operator code did not
  import hazmat Execution Plane APIs directly.

Core fields:

- `contract_version`
- tenant, installation, workspace, project, environment, actor, resource,
  authority, permission decision, idempotency, trace, correlation, and release
  manifest refs
- `scan_ref`
- `caller_repo`
- `forbidden_module`
- `required_facade`
- `violation_ref`
- `scan_status`
- `checked_paths`
- `violations`

### `ExecutionPlane.StreamAttachRevocation.v1`

Purpose:

- records that an active stream attach terminated after grant or lease
  revocation.

Core fields:

- `contract_version`
- tenant, installation, workspace, project, environment, actor, resource,
  authority, permission decision, idempotency, trace, correlation, and release
  manifest refs
- `stream_ref`
- `attach_grant_ref`
- `lease_ref`
- `revocation_ref`
- `termination_ref`
- `last_event_position`

### `CredentialHandleRef.v1`

Purpose:

- reference short-lived secrets, workload identities, or brokered credentials without copying raw long-lived secret material through execution intents

Core fields:

- `contract_version`
- `handle_ref`
- `kind`
- `audience`
- `expires_at`
- `rotation_policy`

### `ExecutionEvent.v1`

Direction:

- Execution Plane -> Spine

Purpose:

- append-only raw execution facts

Core fields:

- `contract_version`
- `event_id`
- `route_id`
- `event_type`
- `timestamp`
- `lineage`
- `payload`

### `ExecutionOutcome.v1`

Direction:

- Execution Plane -> Spine

Purpose:

- terminal or checkpointed execution outcome

Core fields:

- `contract_version`
- `route_id`
- `status`
- `family`
- `raw_payload`
- `artifacts`
- `metrics`
- `failure`
- `lineage`

## Failure Taxonomy

`execution_plane_contracts` must ship a typed failure-class enum that covers at least:

- `policy_denied`
- `route_unresolved`
- `placement_unavailable`
- `launch_failed`
- `transport_failed`
- `protocol_framing_failed`
- `semantic_runtime_failed`
- `approval_expired`
- `lease_expired`
- `attach_mismatch`
- `remote_disconnect`
- `cancellation`
- `timeout`

Each failure class must document:

- primary owner
- retryability expectations
- whether the failure is durable-truth relevant or raw-fact only

## Owner And Mutability Rules

| Contract | Authoritative owner | Mutable after creation? | Notes |
| --- | --- | --- | --- |
| `AuthorityDecision.v1` | Brain | no | superseded by new decision, never edited in place |
| `BoundarySessionDescriptor.v1` | Spine | yes, Spine only | durable state transitions happen here |
| `ExecutionIntentEnvelope.v1` | Spine | no | retries reuse lineage, not in-place mutation |
| family execution intents | family kit, carried by Spine/Execution Plane | no | semantic payload frozen before dispatch |
| `ExecutionRoute.v1` | Spine | yes, by replacement | route changes create a new route instance or superseding revision |
| `ExecutionPlane.AttachGrant.v1` | Execution Plane | no | short-lived grant; expiry creates a new grant |
| `ExecutionPlane.StreamBackpressure.v1` | Execution Plane | yes | stream pressure and termination evidence |
| `ExecutionPlane.WorkerBudget.v1` | Execution Plane | yes | worker admission and pressure-shedding evidence |
| `ExecutionPlane.NoBypassScan.v1` | Execution Plane | yes | source-boundary scan proof |
| `ExecutionPlane.StreamAttachRevocation.v1` | Execution Plane | yes | stream termination after lease or grant revocation |
| `CredentialHandleRef.v1` | credential system / Spine carriage | no | handle rotation occurs behind the ref |
| `ExecutionEvent.v1` | Execution Plane | append-only | never edited in place |
| `ExecutionOutcome.v1` | Execution Plane | no | later durable meaning belongs to Spine, not outcome mutation |

## Replay And Idempotency Rules

- `ExecutionIntentEnvelope.v1` carries the canonical `idempotency_key`
- duplicate dispatches for the same `idempotency_key` and still-valid route must not produce divergent durable meaning
- replay reuses durable lineage and appends new raw execution facts rather than rewriting history
- partial failure reconciliation happens in Spine, not in lower transport packages

## Attach And Reconnect Rules

- attachability is durable truth in `BoundarySessionDescriptor.v1`
- attach grants are ephemeral capabilities expressed through
  `ExecutionPlane.AttachGrant.v1`
- reconnect behavior emits `ExecutionEvent.v1` facts and a terminal or checkpointed `ExecutionOutcome.v1`
- lower runtime state does not replace the durable descriptor

## Secret And Workload Identity Rules

- execution intents carry only `CredentialHandleRef.v1` references
- raw long-lived secrets must not be copied into `ExecutionIntentEnvelope.v1`
- the Execution Plane resolves handles close to execution
- secret scope and expiry must be testable in conformance suites

## Invariants

- `BoundarySessionDescriptor.v1` is durable Spine truth. It is not replaced by lower-plane runtime state.
- `ExecutionEvent.v1` is append-only and may arrive before a terminal `ExecutionOutcome.v1`.
- `ExecutionOutcome.v1` summarizes raw results but does not define durable business meaning; the Spine does that.
- `ExecutionIntentEnvelope.v1` must carry idempotency and deadline semantics.
- placement contracts stay narrow; command semantics do not belong in placement-only types.

## Ownership Rule

Execution-plane contracts live in:

- `/home/home/p/g/n/execution_plane/core/execution_plane_contracts`

They may be carried by:

- `/home/home/p/g/n/jido_integration` (public facade: `Jido.Integration.V2`)
- `/home/home/p/g/n/agent_session_manager`

They must not be exposed wholesale as the public product API of higher repos.
