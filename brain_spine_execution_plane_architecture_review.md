# Brain / Spine / Execution Plane Architecture Review

Date:

- 2026-04-08

## Status Of This Review

This review now records the conclusions that shaped the revised packet.

The original packet had the right direction and the wrong delivery shape.

The revised packet keeps the architecture and changes the program:

- stricter contract specification
- stricter public-surface rules
- stricter failure and identity semantics
- subset-complete capability waves instead of repo-by-repo heroics
- same-wave owner retirement for covered capability slices
- provisional freeze followed by prove-out before broad downstream adoption
- explicit upstream-fix scope when adoption exposes dependency defects

## Executive Verdict

Proceed with the architecture.

Do not weaken the ownership split.

Do not preserve compatibility-shim-first public APIs.

Do not execute the work as a purely sequential family-by-family rewrite.

The corrected version of the packet is staff-level architecture paired with a much safer implementation method.

## What Was Correct From The Start

- the three-way split between Brain, Spine, and Execution Plane
- the need for one honest lower execution owner
- the need to keep semantic family kits above that lower owner
- the need to keep durable truth in the Spine
- the need to keep policy interpretation in the Brain

## What Needed Correction

### 1. The IR was too thin

The earlier packet listed contracts but did not define:

- versioning
- mutability
- failure taxonomy
- replay rules
- attach/reconnect invariants
- credential-handle discipline

The revised packet now does this in:

- `technical/03_shared_contracts_and_lineage.md`

### 2. The public-surface rules were too soft

Without a surface matrix, the Execution Plane would inevitably leak upward.

The revised packet now freezes exposure and carriage rules in:

- `technical/11_surface_exposure_and_contract_carriage_matrix.md`

### 3. The execution plan was too compressed

The earlier packet asked for a big-bang cutover, but the operational shape still read like a giant repo-by-repo rewrite.

The revised packet keeps the final-form target while changing the delivery method to capability waves:

- `technical/10_subset_complete_big_bang_execution_model.md`

The revised packet also narrows the late waves so they are targeted audits and closure passes rather than broad repo-wide rewrites in disguise.

### 4. Quality gates were necessary but not sufficient

Compile, tests, Credo, Dialyzer, and docs are not enough for a runtime-boundary rewrite.

The revised packet adds:

- conformance suites
- failure-class coverage
- replay/idempotency coverage
- lineage continuity checks
- wave gates

## Core Review Position

The right question was never "is the architecture premature?"

The real question was:

- is there already enough architectural drift to justify unification
- and if so, can the implementation plan be made safe enough to survive contact with reality

The revised answer is yes on both counts.

## External Alignment

The revised packet aligns with stable best-practice themes:

- defense in depth rather than one vague sandbox label
- workload identity and short-lived credential handling near execution
- versioned portable context propagation with explicit extension slots
- explicit conformance and fault-injection coverage for shared kernels

## Remaining Non-Negotiables

- no raw long-lived credentials in execution intents
- no repo-local transport ownership after a wave closes for that capability
- no public API that turns the Execution Plane into a universal product-facing library
- no docs that overstate sandbox or isolation guarantees

## Final Recommendation

Build the substrate.

Use the revised packet, not the original delivery shape.

The packet is now much closer to something that can survive a long-lived infra program instead of becoming another clever rewrite that creates a different flavor of ownership drift.
