# `ExecutionPlane.Process.Transport.Subprocess.State`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process/transport/subprocess/state.ex#L3)

Internal state schema for the subprocess transport coordinator.

The GenServer is intentionally a coordinator. This module owns the state
shape and groups fields by responsibility:

* process identity and surface metadata;
* subscriber/event delivery;
* stdout/stderr framing and overflow recovery;
* pending request tasks;
* lifecycle timers and startup options;
* stdin/stdout/interrupt runtime configuration.

Phase 41 owns moving long-line spool file I/O behind its own boundary.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
