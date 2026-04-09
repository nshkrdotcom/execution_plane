# `streaming/execution_plane_sse`

Lower SSE framing, timeout, and stream lifecycle package.

Wave 6 status:

- `ExecutionPlane.SSE.parse/1` owns shared SSE framing
- `ExecutionPlane.SSE.stream/3` owns the lower Finch-backed stream worker and timeout lifecycle
- semantic families consume parsed SSE events without re-owning the lower lane
