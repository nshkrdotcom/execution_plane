# ADR-015: Public Surfaces Expose Mapped Family And Facade IRs, Not Raw Execution Plane Packages

## Decision

The public product-facing surfaces live in family kits, provider SDKs, facades, Brain APIs, and Spine APIs.

`execution_plane` packages may be carried and mapped upward, but they are not the default public surface of higher repos.

If downstream adoption reveals an upstream public-surface defect, that upstream repo is in scope for the minimal fix required to close the active wave.

## Rationale

Without this rule, the Execution Plane would simply become the new mega-library and the ownership cleanup would fail under a different name.
