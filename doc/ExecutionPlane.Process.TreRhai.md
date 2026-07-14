# `ExecutionPlane.Process.TreRhai`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process/tre_rhai.ex#L1)

Local TRE/Rhai process lane for invoking `rex-runner`.

The caller supplies a governed TRE envelope with refs and hashes. This module
resolves script/policy material through an explicit materializer, writes a
bounded local runner workspace, invokes the runner with a cleared environment,
and returns a structured receipt. It does not accept raw policy/script material
in the public envelope.

# `materializer`

```elixir
@type materializer() :: (map() -&gt; {:ok, map()} | {:error, term()})
```

# `receipt`

```elixir
@type receipt() :: map()
```

# `execute`

```elixir
@spec execute(
  map() | keyword(),
  keyword()
) :: {:ok, receipt()} | {:error, receipt()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
