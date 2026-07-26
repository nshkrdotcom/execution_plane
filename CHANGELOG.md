# Changelog

## 0.2.0 - 2026-07-27

- Correct the public package topology: `execution_plane` is now the core-only
  common substrate, while process and JSON-RPC are independently published
  components.
- Add interactive runtime lifecycle contracts and boundary codecs to the
  common package.
- Correct the node package's contract claim: its current admission and
  one-shot dispatch surface implements `ExecutionPlane.Node.Client`, while
  `ExecutionPlane.Runtime.Client` remains the distinct interactive lifecycle
  contract.
- Require clean Hex-resolved component compilation after the core release so
  workspace paths cannot mask a duplicate-module or stale-registry graph.

## 0.1.0 - 2026-07-13

- Prepare the first public `execution_plane` distribution as a released Weld
  0.8.4 monolith of the common substrate, JSON-RPC framing, and process runtime.
- Keep HTTP, SSE, WebSocket, node, and operator-terminal components outside the
  frozen foundation package.
- Replace component-application self-start assumptions with bounded supervisor
  readiness while preserving real `:erlexec` startup.
- Add generated-package topology, dependency, module-ownership, and clean
  local-override consumer proofs.
