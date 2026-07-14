# `ExecutionPlane.LineFraming`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/line_framing.ex#L1)

Incremental newline framing for stdout and stderr stream handling.

# `t`

```elixir
@type t() :: %ExecutionPlane.LineFraming{buffer: binary()}
```

# `empty?`

```elixir
@spec empty?(t()) :: boolean()
```

Returns `true` when there is no buffered partial line.

# `flush`

```elixir
@spec flush(t()) :: {[binary()], t()}
```

Flushes a trailing partial fragment as a final line.

# `new`

```elixir
@spec new(binary()) :: t()
```

Creates a new framing state.

# `push`

```elixir
@spec push(t(), iodata()) :: {[binary()], t()}
```

Pushes a binary chunk into the framer and returns complete lines.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
