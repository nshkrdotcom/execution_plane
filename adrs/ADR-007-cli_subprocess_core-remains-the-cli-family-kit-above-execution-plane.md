# ADR-007: `cli_subprocess_core` Remains The CLI Family Kit Above The Execution Plane

## Decision

`/home/home/p/g/n/cli_subprocess_core` remains the CLI family kit.

It will sit above `/home/home/p/g/n/execution_plane`.

It will not remain the owner of raw lower process/runtime mechanics.

## Rationale

The repo already has the right family-kit shape.
The missing correction is lower ownership, not removal of the family kit itself.

Process, PTY, and lower JSON-RPC runtime mechanics move below it. CLI planning and session semantics stay above it.
