# `ExecutionPlane.Placements.Capabilities`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/placements/capabilities.ex#L1)

Narrow placement-surface capabilities carried independently from command or
provider semantics.

# `t`

```elixir
@type t() :: %ExecutionPlane.Placements.Capabilities{
  interrupt_kind: :signal | :stdin | :rpc | :none,
  path_semantics: :local | :remote | :guest,
  remote?: boolean(),
  startup_kind: :spawn | :attach | :bridge,
  supports_cwd?: boolean(),
  supports_env?: boolean(),
  supports_pty?: boolean(),
  supports_run?: boolean(),
  supports_streaming_stdio?: boolean(),
  supports_user?: boolean()
}
```

# `new`

```elixir
@spec new(t() | map() | keyword()) ::
  {:ok, t()} | {:error, {:invalid_capabilities, term()}}
```

# `new!`

```elixir
@spec new!(t() | map() | keyword()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
