# Quality Gates, Docs, And Execution Rules

## Every Implementation Prompt Must Enforce

- every touched repo or packet target runs the commands defined in `technical/12_repo_quality_gate_command_matrix.md`
- all tests pass where applicable
- compile is warning-free where applicable
- no errors remain
- no Credo issues remain where applicable
- no Dialyzer issues remain where applicable
- `mix format` has been run where applicable
- `mix docs` runs without warnings where applicable
- guides and `README.md` content are updated to match the as-built architecture

## Additional Conformance Gates

For any wave that changes the Brain-to-Spine boundary, Spine-to-Execution boundary, lower transport behavior, or attach/reconnect semantics, the wave must also add or update:

- contract conformance tests
- route resolution tests
- attach/reconnect tests
- replay/idempotency tests
- failure-class coverage
- lineage continuity tests
- cross-surface equivalence tests where relevant
- credential-handle and expiry tests where relevant

## Wave Gate Rule

Every capability wave closes only when:

- the repo subset for that wave is green
- the covered capability uses final-form contracts and public surfaces
- old owners for that covered capability are retired, removed, or made provably unreachable in the same wave
- conformance coverage exists for the contracts and failure classes touched
- docs and guides describe the new owner clearly

No next wave may rely on a previous wave that has not met its gate.

Late verification waves may audit for owner drift, but they must not be the intended place where real retirement first happens.

## Provisional Freeze Rule

Wave 1 is allowed to freeze:

- topology
- public-surface rules
- core lineage and failure semantics

Wave 1 is not allowed to pretend that all family-specific minimal-lane intent details are permanently proven before Wave 3.

Wave 3 is the explicit prove-out and correction wave for minimal-lane contracts and surfaces.

## Upstream Fix Scope Rule

If a wave exposes an upstream defect in a dependency repo that blocks closure of the current wave:

- that upstream repo is explicitly in scope for the minimal fix required
- the upstream repo must run its relevant gates
- the impacted downstream repo must rerun its relevant gates
- the checklist must record the upstream repo touch and the reason

## Brain Repo Rule (Updated 2026-04-24)

The Brain is `/home/home/p/g/n/citadel`.

- `JIDO_BRAIN_CONTRACT_CONTEXT/` preserves the packet's Brain-side contract lineage
- read `citadel`'s `AGENTS.md` and source as the current Brain-side truth
- when a Brain-side contract ambiguity arises, consult `citadel` source first
- Brain-side changes are in scope under ADR-016 when adoption exposes a dependency defect in `citadel`

## Gate Command Rule

- the command source of truth is `technical/12_repo_quality_gate_command_matrix.md`
- repos may use documented repo-local equivalents where the command matrix says so
- commands are not considered optional because a prompt forgot to spell them out

## Commit Metadata Rule

- `prompts/commit-message.txt` must provide a same-wave commit section for every primary target repo named in `prompts/prompts.txt`
- `prompts/commit-message.txt` may additionally provide same-wave commit sections for prompt-declared named conditional upstream repos listed in the prompt's `## Conditional Upstream Scope` section
- commit target names must resolve to a repo name declared in `prompts/runner_config.exs`
- packet-local validation must reject optional same-wave commit sections whose targets are outside that wave's primary or named conditional scope

## ADR-016 Scope Promotion Rule

If ADR-016 forces a same-wave upstream touch outside the prompt's currently named conditional scope:

- first update that wave's prompt to name the repo under `## Conditional Upstream Scope`
- then update that wave's checklist to mirror the same named scope
- then add the same-wave commit section in `prompts/commit-message.txt`
- then rerun packet-local metadata validation
- only after those updates may that repo be treated as valid same-wave optional scope (see Brain Repo Rule above for how to handle Brain-side defects in `citadel`)

## Wave Evidence Rule

Every checklist must record:

- repos actually touched
- upstream repos touched beyond the primary target list
- commands run
- gate evidence summary
- retirement completed for the covered capability
- blockers or deviations

## Docs Rule

When a repo already publishes HexDocs, each implementation prompt must:

- update `README.md`
- update or add `guides/*.md`
- update `mix.exs` docs extras and menu groups when new guides are added
- document ownership boundaries explicitly
- avoid claiming stronger isolation or sandboxing than the code actually provides

## Test Strategy Rule

Every prompt must use TDD/RGR:

- write or update the failing tests first
- implement the end-state behavior
- re-run the owned repo quality gates
- fix forward until green

## Recontextualization Rule

Every prompt/checklist pair must require the implementation agent to:

1. on every resume or after every compaction, re-read the prompt
2. re-read the checklist
3. re-read all required reading paths named in the prompt
4. update checklist state before resuming work and keep it current throughout the wave
5. continue from the final architecture and current wave gate, not from partial local memory

## Architecture Rule

All prompts in this packet implement final-form architecture through subset-complete capability waves.

They are not allowed to:

- land intermediate public APIs as the target
- keep duplicate runtime owners alive after a wave closes
- add compatibility shims as the long-term surface
- preserve old repo-local transport code because it is convenient
- collapse semantic family kits into the Execution Plane
- pass raw long-lived credentials through execution intents
