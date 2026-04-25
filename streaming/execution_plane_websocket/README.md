# `streaming/execution_plane_websocket`

Lower WebSocket session and handshake lifecycle package.

Current status:

- active as a separate Mix project that depends on root `execution_plane`
- owns handshake, receive, ping/pong, timeout, and close handling
- exposes a lane adapter for hosts that select this realtime lane
- semantic families keep provider frame decoding above this package
- reconnect and resume policy stay contract-driven above the lower socket lifecycle
