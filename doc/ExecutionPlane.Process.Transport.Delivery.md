# `ExecutionPlane.Process.Transport.Delivery`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process/transport/delivery.ex#L1)

Stable mailbox-delivery metadata for transport subscribers.

Direct adapters can use this metadata together with
`ExecutionPlane.Process.Transport.extract_event/1` and
`ExecutionPlane.Process.Transport.extract_event/2` to relay transport events
without depending on internal worker identity.

# `t`

```elixir
@type t() :: %ExecutionPlane.Process.Transport.Delivery{
  default_subscription_tag: :subscriber_pid,
  message_shape: :tagged,
  tagged_event_tag: atom()
}
```

# `new`

```elixir
@spec new(atom()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
