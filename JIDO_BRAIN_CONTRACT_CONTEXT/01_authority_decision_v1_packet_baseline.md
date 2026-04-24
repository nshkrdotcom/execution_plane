# AuthorityDecision.v1 Packet Baseline

## Purpose

This file captures the Brain-side contract baseline for `citadel`.

## Ownership And Flow

- contract owner: `citadel`
- carrier and durable persistence owner: `jido_integration`
- downstream flow: Brain -> Spine -> family or facade -> Execution Plane

## Required Core Fields

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

## Required Semantic Invariants

- `AuthorityDecision.v1` remains a policy and topology contract, not a transport or runtime contract.
- `decision_id` and `decision_hash` must be stable enough for replay, audit, and durable linkage.
- `boundary_class`, `trust_profile`, `approval_profile`, `egress_profile`, `workspace_profile`, and `resource_profile` are policy dimensions and must not be reinterpreted as lower transport mechanics.
- `jido_integration` may persist, echo, route, and project Brain-authored intent, but it may not invent new Brain policy locally.
- the Execution Plane may enforce lower runtime behavior and resolve handles near execution, but it may not reinterpret Brain policy.
- raw long-lived credentials do not belong in this contract or in downstream execution intents.
- sandbox or isolation strength must be represented explicitly by policy and placement dimensions rather than inferred from a marketing name.

## Packet-Local Usage

- Wave 1 aligns vocabulary and contract ownership around this baseline.
- Wave 5 freezes durable, approval, replay, identity, attach, and outcome semantics against this baseline.
- Wave 6 is allowed to converge session-bearing lanes on top of the Wave 5 freeze, but it is not allowed to redefine Brain policy semantics ad hoc.

## Versioning Rule

If the Brain contract needs different required fields or different field semantics, that is a contract-version event, not an incidental doc tweak. The change should introduce `AuthorityDecision.v2` or another explicitly versioned successor and migrate the packet deliberately.
