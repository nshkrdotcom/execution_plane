# `streaming/execution_plane_sse`

Lower SSE framing, timeout, and stream lifecycle package.

Current status:

- active as a separate Mix project that depends on root `execution_plane`
- owns shared SSE framing
- owns the lower Finch-backed stream worker and timeout lifecycle
- exposes a lane adapter for hosts that select this realtime lane
- semantic families consume parsed SSE events without re-owning the lower lane
