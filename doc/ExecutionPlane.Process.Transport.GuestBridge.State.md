# `ExecutionPlane.Process.Transport.GuestBridge.State`
[🔗](https://github.com/nshkrdotcom/execution_plane/blob/v0.1.0/lib/execution_plane/process/transport/guest_bridge/state.ex#L3)

Internal state schema for the guest bridge transport coordinator.

The GenServer owns callback sequencing. This module owns the state shape for
socket identity, stream framing, subscribers, and request tracking.

Phase 42 caps this state schema at 32 fields. Any future field addition must
either remove an existing field or introduce a narrower nested state owner.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
