# ADR-001: Brain, Spine, And Execution Plane Are The Top-Level System Split

## Decision

The top-level system split is:

- Brain: `/home/home/p/g/n/citadel`
- Spine: `/home/home/p/g/n/jido_integration`
- Execution Plane: `/home/home/p/g/n/execution_plane`

## Rationale

This is the clearest separation of authority, durable boundary truth, and live transport mechanics.

The lower layer owns execution facts, not durable execution truth.

## Scope Update (2026-04-24)

The current plan also includes layers above the original three-layer model:

- `/home/home/p/g/n/mezzanine` — durable business-semantics substrate; owns Temporal workflow runtime, PackModel, lifecycle engine, promotion coordinator, proof tokens, and audit
- `/home/home/p/g/n/outer_brain` — semantic-runtime gateway; owns recall orchestration, private memory write, context pack assembly, SemanticProvider contract
- `/home/home/p/g/n/app_kit` — northbound product boundary; owns product boundary enforcement (`mix app_kit.no_bypass`), operator/work/review surfaces
- `/home/home/p/g/n/extravaganza` — product proving ground; thin product above AppKit
- `/home/home/p/g/n/ground_plane` — shared lower primitives (Id, Lease, Fence, HandoffState, Checkpoint, postgres/projection helpers)
- `/home/home/p/g/n/AITrace` — unified observability layer

The original decision stands: the three layers own what they own, and no layer may cross boundaries. The expanded stack makes the governance, semantic runtime, and product boundary layers explicit above Spine.

See: `/home/home/jb/docs/20260424/foundational_stack_architecture_synthesis/foundational_architecture_synthesis.md`
