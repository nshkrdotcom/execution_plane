# Usage

## Ordinary unary requests

The existing helper remains `ExecutionPlane.HTTP.unary/2`.

```elixir
{:ok, result} =
  ExecutionPlane.HTTP.unary(
    %{
      url: "https://example.com/status",
      method: "GET"
    },
    lineage: %{idempotency_key: "status-check"}
  )
```

This path remains synchronous from the caller's point of view and preserves the
existing kernel dispatch, event, outcome, and failure semantics.

## Cancelable unary requests

Use `start_unary/2`, `await_unary/2`, and `cancel_unary/2` when the caller needs
a real lower-transport cancellation handle:

```elixir
{:ok, session} =
  ExecutionPlane.HTTP.start_unary(
    %{
      url: "https://example.com/slow",
      method: "GET",
      timeout_ms: 30_000
    },
    lineage: %{idempotency_key: "slow-check"}
  )

# May be called from another BEAM process.
:ok = ExecutionPlane.HTTP.cancel_unary(session, :caller_cancelled)

case ExecutionPlane.HTTP.await_unary(session, 5_000) do
  {:error, result} ->
    :cancellation = result.outcome.failure.failure_class

  {:ok, result} ->
    result
end
```

`start_unary/2` executes through the normal `ExecutionPlane.Kernel` path. The
HTTP protocol package switches only the lower request to `:httpc` asynchronous
mode so the request-owning worker receives an active request ID.
`cancel_unary/2` sends cancellation to that worker, which calls
`ExecutionPlane.Protocols.HTTP.cancel_request/1`; the latter delegates directly
to `:httpc.cancel_request/1`.

The start process owns terminal result delivery and therefore must perform
`await_unary/2`. Cross-process cancellation is supported. Repeated cancellation
and cancellation after normal completion are harmless. An await timeout also
requests lower cancellation before returning `{:error, :timeout}`. The default
await timeout is `:infinity`; the request/kernel timeout remains the normal
owner of transport timeout semantics.

`:httpc.cancel_request/1` is itself asynchronous with respect to request
completion. If the response has already won that race, `await_unary/2` may
return the normal result even though a concurrent `cancel_unary/2` returns
`:ok`. The session still produces only one kernel terminal outcome.

Cancellation only establishes what happened locally at the HTTP transport. It
does not prove that the remote server never received the request, does not roll
back remote side effects, and does not provide exactly-once semantics. The
caller-provided cancellation reason is not emitted into the execution outcome
or raw payload.

## Lower transport primitives

`ExecutionPlane.Protocols.HTTP.start_request/6` and `cancel_request/1` are the
low-level `:httpc` primitives used by the session lifecycle. Semantic callers
should normally prefer `ExecutionPlane.HTTP` so kernel lineage and outcome
construction remain intact.

The package also exposes the lower lane adapter behavior for hosts that need to
register the HTTP lane explicitly.
