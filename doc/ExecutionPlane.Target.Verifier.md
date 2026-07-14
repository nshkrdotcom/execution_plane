# `ExecutionPlane.Target.Verifier`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/boundary.ex#L471)

Target attestation verifier behaviour.

# `attestation_types`

```elixir
@callback attestation_types() :: [String.t()]
```

# `capability_classes`

```elixir
@callback capability_classes() :: [String.t()]
```

# `handles?`

```elixir
@callback handles?(ExecutionPlane.Target.Attestation.t() | map()) :: boolean()
```

# `verifier_id`

```elixir
@callback verifier_id() :: String.t()
```

# `verify`

```elixir
@callback verify(
  ExecutionPlane.Target.Attestation.t() | map(),
  keyword()
) ::
  {:ok, ExecutionPlane.Target.Descriptor.t()}
  | {:error, ExecutionPlane.Admission.Rejection.t()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
