# `protocols/execution_plane_jsonrpc`

Owns lower JSON-RPC framing and control-lane handling below provider or family
semantics.

Current status:

- active as a separate Mix project that depends on root `execution_plane`
- owns JSON-RPC request/response framing and correlation
- exposes a lane adapter for hosts that explicitly compose JSON-RPC with a
  target client
- does not own subprocess launch; a host that wants JSON-RPC over a process
  must compose this package with the process lane explicitly
- family kits keep protocol-session orchestration above this lower framing seam
