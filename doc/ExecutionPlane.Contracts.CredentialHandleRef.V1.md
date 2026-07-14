# `ExecutionPlane.Contracts.CredentialHandleRef.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/credential_handle_ref/v1.ex#L1)

Reference to short-lived execution-time secret or workload identity material.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.CredentialHandleRef.V1{
  audience: String.t(),
  contract_version: String.t(),
  expires_at: String.t() | nil,
  handle_ref: String.t(),
  kind: String.t(),
  rotation_policy: String.t() | nil
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
