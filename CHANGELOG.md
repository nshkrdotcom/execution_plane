# Changelog

## 0.1.0 - 2026-07-13

- Prepare the first public `execution_plane` distribution as a released Weld
  0.8.2 monolith of the common substrate, JSON-RPC framing, and process runtime.
- Keep HTTP, SSE, WebSocket, node, and operator-terminal components outside the
  frozen foundation package.
- Replace component-application self-start assumptions with bounded supervisor
  readiness while preserving real `:erlexec` startup.
- Add generated-package topology, dependency, module-ownership, and clean
  local-override consumer proofs.
