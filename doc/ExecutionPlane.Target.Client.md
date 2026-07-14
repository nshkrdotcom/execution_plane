# `ExecutionPlane.Target.Client`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/boundary.ex#L483)

Node-to-Target execution client behaviour.

# `cancel`

```elixir
@callback cancel(
  ExecutionPlane.ExecutionRef.t(),
  keyword()
) :: :ok | {:error, term()}
```

# `describe`

```elixir
@callback describe(keyword()) :: {:ok, map()} | {:error, term()}
```

# `execute`

```elixir
@callback execute(
  ExecutionPlane.ExecutionRequest.t(),
  keyword()
) ::
  {:ok, ExecutionPlane.ExecutionResult.t()}
  | {:error, ExecutionPlane.ExecutionResult.t()}
```

# `stream`

```elixir
@callback stream(
  ExecutionPlane.ExecutionRequest.t(),
  keyword()
) :: {:ok, Enumerable.t()} | {:error, ExecutionPlane.Admission.Rejection.t()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
