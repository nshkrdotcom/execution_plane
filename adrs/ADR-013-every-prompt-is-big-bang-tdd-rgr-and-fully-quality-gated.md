# ADR-013: Every Prompt Is Final-Form, TDD/RGR, And Fully Quality Gated

## Decision

Every implementation prompt in `prompts/` must require:

- final-form implementation only
- TDD/RGR
- docs and guide updates
- `mix format`
- tests passing
- warning-free compile
- zero Credo issues where applicable
- zero Dialyzer issues where applicable
- warning-free docs generation where applicable
- conformance coverage when shared contracts or lower runtime behavior change
- explicit wave-gate closure before the next prompt relies on the covered capability
- the exact repo command set from `technical/12_repo_quality_gate_command_matrix.md`
- checklist evidence recording for repos touched, commands run, upstream fixes, and gate evidence

## Rationale

The prompt chain must encode the quality bar directly instead of relying on memory or convention.
