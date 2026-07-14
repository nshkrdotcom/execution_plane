# `ExecutionPlane.Process.Transport.Info`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process/transport/info.ex#L1)

Snapshot of a long-lived transport's execution-surface metadata and IO contract.

# `t`

```elixir
@type t() :: %ExecutionPlane.Process.Transport.Info{
  adapter_capabilities:
    ExecutionPlane.Process.Transport.Surface.Capabilities.t() | nil,
  adapter_metadata: map(),
  boundary_class: ExecutionPlane.Process.Transport.Surface.boundary_class(),
  bridge_profile: String.t() | nil,
  delivery: ExecutionPlane.Process.Transport.Delivery.t() | nil,
  effective_capabilities:
    ExecutionPlane.Process.Transport.Surface.Capabilities.t() | nil,
  extensions: map(),
  interrupt_mode: :signal | {:stdin, binary()},
  invocation: ExecutionPlane.Command.t() | nil,
  lease_ref: String.t() | nil,
  observability: map(),
  os_pid: pos_integer() | nil,
  pid: pid() | nil,
  protocol_version: pos_integer() | nil,
  pty?: boolean(),
  status: :connected | :disconnected | :error,
  stderr: binary(),
  stdin_mode: :line | :raw,
  stdout_mode: :line | :raw,
  surface_kind: ExecutionPlane.Process.Transport.surface_kind(),
  surface_ref: String.t() | nil,
  target_id: String.t() | nil
}
```

# `disconnected`

Returns the default disconnected transport snapshot.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
