# `ExecutionPlane.Lane.Adapter`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/boundary.ex#L395)

Transport lane adapter behaviour.

# `capabilities`

```elixir
@callback capabilities() :: ExecutionPlane.Lane.Capabilities.t()
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

# `lane_id`

```elixir
@callback lane_id() :: atom()
```

# `stream`

```elixir
@callback stream(
  ExecutionPlane.ExecutionRequest.t(),
  keyword()
) :: {:ok, Enumerable.t()} | {:error, ExecutionPlane.Admission.Rejection.t()}
```

# `validate`

```elixir
@callback validate(ExecutionPlane.ExecutionRequest.t()) ::
  :ok | {:error, ExecutionPlane.Admission.Rejection.t()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
