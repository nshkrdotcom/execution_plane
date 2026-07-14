# `ExecutionPlane.RemoteFacade.Lane`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/remote_facade/lane.ex#L1)

Execution Plane-owned lower lane facade for distributed StackLab profiles.

Lower lane execution is bounded by Execution Plane contracts. The default
facade supports the diagnostic lane for deterministic local proof and returns
serializable receipt maps.

# `execute_lane`

```elixir
@spec execute_lane(
  map(),
  keyword()
) :: {:ok, map()} | {:error, map()}
```

# `owner_group`

```elixir
@spec owner_group() :: {module(), :lane}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
