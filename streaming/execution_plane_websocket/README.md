# `streaming/execution_plane_websocket`

Lower WebSocket session and handshake lifecycle package.

Wave 6 status:

- `ExecutionPlane.WebSocket.stream/4` owns handshake, receive, ping/pong, timeout, and close handling
- semantic families keep provider frame decoding above this package
- reconnect and resume policy stay contract-driven above the lower socket lifecycle
