# `ExecutionPlane.Process.Transport.Surface.Capabilities`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process/transport/surface/capabilities.ex#L1)

Typed transport-family and per-session execution-surface capabilities.

# `interrupt_kind`

```elixir
@type interrupt_kind() :: :signal | :stdin | :rpc | :none
```

# `key`

```elixir
@type key() ::
  :remote?
  | :startup_kind
  | :path_semantics
  | :supports_run?
  | :supports_streaming_stdio?
  | :supports_pty?
  | :supports_user?
  | :supports_env?
  | :supports_cwd?
  | :interrupt_kind
```

# `path_semantics`

```elixir
@type path_semantics() :: :local | :remote | :guest
```

# `startup_kind`

```elixir
@type startup_kind() :: :spawn | :attach | :bridge
```

# `t`

```elixir
@type t() :: %ExecutionPlane.Process.Transport.Surface.Capabilities{
  interrupt_kind: interrupt_kind(),
  path_semantics: path_semantics(),
  remote?: boolean(),
  startup_kind: startup_kind(),
  supports_cwd?: boolean(),
  supports_env?: boolean(),
  supports_pty?: boolean(),
  supports_run?: boolean(),
  supports_streaming_stdio?: boolean(),
  supports_user?: boolean()
}
```

# `validation_error`

```elixir
@type validation_error() ::
  {:invalid_capabilities, term()}
  | {:invalid_remote, term()}
  | {:invalid_startup_kind, term()}
  | {:invalid_path_semantics, term()}
  | {:invalid_supports_run, term()}
  | {:invalid_supports_streaming_stdio, term()}
  | {:invalid_supports_pty, term()}
  | {:invalid_supports_user, term()}
  | {:invalid_supports_env, term()}
  | {:invalid_supports_cwd, term()}
  | {:invalid_interrupt_kind, term()}
```

# `keys`

```elixir
@spec keys() :: [key(), ...]
```

# `new`

```elixir
@spec new(t() | keyword() | map()) :: {:ok, t()} | {:error, validation_error()}
```

# `new!`

```elixir
@spec new!(t() | keyword() | map()) :: t()
```

# `satisfies_requirements?`

```elixir
@spec satisfies_requirements?(t(), map() | keyword() | t()) :: boolean()
```

# `subset?`

```elixir
@spec subset?(t(), t()) :: boolean()
```

# `to_map`

```elixir
@spec to_map(t()) :: map()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
