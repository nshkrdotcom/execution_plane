# `ExecutionPlane.Contracts.HttpExecutionIntent.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/http_execution_intent/v1.ex#L1)

HTTP-family execution intent.

The payload fields below `envelope` are frozen as the minimal Wave 1 lane
surface, but their detailed semantics stay provisional until Wave 3.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.HttpExecutionIntent.V1{
  body: term() | nil,
  contract_version: String.t(),
  egress_surface: map(),
  envelope: ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1.t(),
  headers: map(),
  request_shape: String.t(),
  retry_class: String.t() | nil,
  stream_mode: String.t(),
  timeouts: map()
}
```

# `contract_version`

```elixir
@spec contract_version() :: String.t()
```

# `dump`

```elixir
@spec dump(t()) :: map()
```

# `new`

```elixir
@spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Exception.t()}
```

# `new!`

```elixir
@spec new!(map() | keyword() | t()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
