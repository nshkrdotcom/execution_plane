# `ExecutionPlane`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane.ex#L1)

Lower-runtime substrate for shared execution contracts and runtime helpers.

# `active_mix_projects`

```elixir
@spec active_mix_projects() :: [atom(), ...]
```

Returns the final active Mix project app names.

# `identity`

```elixir
@spec identity() :: :execution_plane
```

Returns the root identity for the workspace shell.

## Examples

    iex> ExecutionPlane.identity()
    :execution_plane

# `minimal_first_cut`

```elixir
@spec minimal_first_cut() :: [atom(), ...]
```

Returns the final active Mix project app names.

# `package_homes`

```elixir
@spec package_homes() :: %{required(atom()) =&gt; String.t()}
```

Returns the active package homes keyed by their runtime role.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
