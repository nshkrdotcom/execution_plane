# Changelog

## 0.2.0 - 2026-09-17

- Add cancelable unary HTTP sessions with `ExecutionPlane.HTTP.start_unary/2`,
  `await_unary/2`, and `cancel_unary/2` while preserving the existing kernel
  dispatch/result lifecycle.
- Expose the lower `ExecutionPlane.Protocols.HTTP.start_request/6` and
  `cancel_request/1` primitives backed by asynchronous `:httpc` requests and
  physical `:httpc.cancel_request/1` cancellation.
- Normalize cancelled unary sessions through the existing shared
  `:cancellation` failure class and keep ordinary `unary/2` behavior unchanged.
- Add a real `:gen_tcp` holding-server acceptance test that observes the client
  socket closing after cancellation and rejects late successful completion.
- Document owner-bound await semantics, cross-process cancellation, timeout
  cleanup, completion/cancellation race semantics, cancellation-reason
  redaction, and the fact that local cancellation cannot roll back a remote
  side effect that may already have begun.

## 0.1.0 - 2026-09-16

- Refresh all direct dependency requirements to current stable releases and update
  the complete resolved dependency graph (2026-09-16).

- Initial standalone unary HTTP lane, including direct and runtime-client execution.
- Default to the published `execution_plane ~> 0.3.0` dependency for all Mix tasks.
  Local source substitution uses the standard workspace bootstrap hook.
- Pin chunk sizes in bitstring matches for warning-free compilation.