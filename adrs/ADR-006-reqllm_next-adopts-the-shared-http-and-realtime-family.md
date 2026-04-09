# ADR-006: `reqllm_next` Adopts The Shared HTTP And Realtime Execution Substrate

## Decision

`/home/home/p/g/n/reqllm_next` keeps provider, session, model, and realtime semantics but stops owning direct HTTP, SSE, and WebSocket runtime mechanics.

It converges on `/home/home/p/g/n/execution_plane` for lower HTTP and realtime execution.

## Rationale

This puts `reqllm_next` on the same backend substrate as the broader HTTP family without flattening provider semantics into another family kit.
