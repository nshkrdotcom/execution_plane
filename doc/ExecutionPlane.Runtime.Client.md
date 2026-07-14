# `ExecutionPlane.Runtime.Client`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/boundary.ex#L763)

Consumer-to-node runtime client behaviour.

# `admit`

```elixir
@callback admit(
  ExecutionPlane.Admission.Request.t(),
  keyword()
) ::
  {:ok, ExecutionPlane.Admission.Decision.t()}
  | {:error, ExecutionPlane.Admission.Rejection.t()}
```

# `cancel`

```elixir
@callback cancel(
  ExecutionPlane.ExecutionRef.t(),
  keyword()
) :: :ok | {:error, term()}
```

# `describe`

```elixir
@callback describe(keyword()) ::
  {:ok, ExecutionPlane.Runtime.NodeDescriptor.t()} | {:error, term()}
```

# `execute`

```elixir
@callback execute(
  ExecutionPlane.Admission.Request.t(),
  keyword()
) ::
  {:ok, ExecutionPlane.ExecutionResult.t()}
  | {:error, ExecutionPlane.ExecutionResult.t()}
```

# `stream`

```elixir
@callback stream(
  ExecutionPlane.Admission.Request.t(),
  keyword()
) :: {:ok, Enumerable.t()} | {:error, ExecutionPlane.Admission.Rejection.t()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
