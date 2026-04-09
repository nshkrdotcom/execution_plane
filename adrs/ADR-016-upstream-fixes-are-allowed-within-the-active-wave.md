# ADR-016: Upstream Fixes Are Allowed Within The Active Wave

## Decision

If a wave exposes an upstream defect in a dependency repo that blocks closure of the active capability slice:

- the upstream repo is explicitly in scope for the minimal required fix
- the upstream repo must run its relevant gates
- the impacted downstream repo must rerun its relevant gates
- the checklist must record the upstream touch and the reason
- if the upstream repo is outside the wave's currently named conditional scope, first amend the wave prompt, the wave checklist, and `prompts/commit-message.txt` to name it, then rerun packet metadata validation before committing

## Rationale

Dependent adoption waves are not realistic if they forbid touching the upstream family or contract owner whose defect was just exposed.

The correct boundary is not "never touch upstream."

The correct boundary is:

- touch upstream only when needed to close the active wave
- keep the fix minimal and wave-scoped
- promote unnamed upstream scope into named wave scope before commit metadata is considered valid
- rerun gates and record evidence
