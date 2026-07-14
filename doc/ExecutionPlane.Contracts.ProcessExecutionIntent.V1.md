# `ExecutionPlane.Contracts.ProcessExecutionIntent.V1`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/contracts/process_execution_intent/v1.ex#L1)

Process-family execution intent.

`execution_surface`, `env_projection`, and `shutdown_policy` are frozen as
Wave 1 carrier fields only. Detailed minimal-lane semantics remain
provisional until Wave 3.

# `t`

```elixir
@type t() :: %ExecutionPlane.Contracts.ProcessExecutionIntent.V1{
  argv: [String.t()],
  clear_env: boolean(),
  close_stdin: boolean(),
  command: String.t(),
  contract_version: String.t(),
  cwd: String.t() | nil,
  env_projection: map(),
  envelope: ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1.t(),
  execution_surface: map(),
  shutdown_policy: map(),
  stderr_mode: String.t(),
  stdin: term() | nil,
  stdio_mode: String.t(),
  user: String.t() | nil
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
