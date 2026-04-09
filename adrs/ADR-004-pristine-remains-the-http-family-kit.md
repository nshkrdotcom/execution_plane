# ADR-004: `pristine` Remains The HTTP Family Kit

## Decision

`/home/home/p/g/n/pristine` remains the shared HTTP semantic runtime.

It emits `HttpExecutionIntent.v1` and delegates lower execution to `/home/home/p/g/n/execution_plane`.

## Rationale

`pristine` already owns the correct semantic layer:

- request normalization
- serialization
- auth shaping
- resilience
- telemetry

The new lower HTTP substrate exists beneath `pristine`, not instead of it.
