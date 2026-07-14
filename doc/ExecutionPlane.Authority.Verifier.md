# `ExecutionPlane.Authority.Verifier`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/boundary.ex#L273)

Authority verifier behaviour registered by node hosts.

# `verifier_id`

```elixir
@callback verifier_id() :: String.t()
```

# `verify`

```elixir
@callback verify(
  ExecutionPlane.Authority.Ref.t() | map(),
  keyword()
) :: {:ok, map()} | {:error, ExecutionPlane.Admission.Rejection.t()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
