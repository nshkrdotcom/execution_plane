# Execution Plane Node

`execution_plane_node` is the lane-neutral control-plane runtime. Hosts select
lane adapters, Target verifiers, evidence sinks, and the authority verifier by
declaring their own dependencies and registering those modules before admission
is opened.

The package depends on root `execution_plane` only. It does not require
`execution_plane_process`, `execution_plane_http`, `execution_plane_sse`,
`execution_plane_websocket`, or `execution_plane_jsonrpc`.
