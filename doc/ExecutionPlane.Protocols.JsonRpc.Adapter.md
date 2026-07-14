# `ExecutionPlane.Protocols.JsonRpc.Adapter`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/protocols/json_rpc/adapter.ex#L1)

Execution Plane-owned JSON-RPC framing adapter for persistent lanes.

Family kits keep protocol-session orchestration and provider semantics above
this adapter while the canonical request/response framing and correlation live
below them.

# `t`

```elixir
@type t() :: %ExecutionPlane.Protocols.JsonRpc.Adapter{
  next_id: non_neg_integer(),
  ready_matcher: (map() -&gt; boolean()) | nil
}
```

# `encode_notification`

```elixir
@spec encode_notification(term(), t()) :: {:ok, binary(), t()} | {:error, term()}
```

# `encode_once`

```elixir
@spec encode_once(term()) :: binary()
```

# `encode_peer_reply`

```elixir
@spec encode_peer_reply(term(), {:ok, term()} | {:error, term()}, t()) ::
  {:ok, binary(), t()}
```

# `encode_request`

```elixir
@spec encode_request(term(), t()) :: {:ok, term(), binary(), t()} | {:error, term()}
```

# `handle_inbound`

```elixir
@spec handle_inbound(binary(), t()) :: {:ok, [term()], t()}
```

# `init`

```elixir
@spec init(keyword()) :: {:ok, t(), [binary()]}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
