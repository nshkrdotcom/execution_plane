# `protocols/execution_plane_jsonrpc`

Owns lower JSON-RPC framing and control-lane handling below provider or family
semantics.

Wave 6 status:

- active for unary JSON-RPC request/response over the process runtime
- `ExecutionPlane.Protocols.JsonRpc.Adapter` now owns the shared persistent JSON-RPC framing adapter
- family kits keep protocol-session orchestration above this lower framing seam
