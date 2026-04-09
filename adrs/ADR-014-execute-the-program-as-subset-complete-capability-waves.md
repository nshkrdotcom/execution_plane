# ADR-014: Execute The Program As Subset-Complete Capability Waves

## Decision

The implementation program proceeds through capability waves rather than repo silos.

Each wave defines:

- a bounded functionality subset
- a bounded repo subset
- a wave gate that retires the old owner for the covered capability

The program also uses:

- provisional freeze for topology and core lineage rules before prove-out
- prove-out and correction before broad downstream adoption of minimal-lane contracts
- targeted late verification waves rather than repo-wide cleanup sweeps

## Rationale

This preserves the final-form architecture while making the rollout mechanically verifiable.

It is the safer middle path between:

- a single heroic rewrite
- and a compatibility migration that preserves permanent ownership drift
