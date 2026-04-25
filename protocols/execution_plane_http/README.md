# `protocols/execution_plane_http`

Owns lower HTTP execution primitives and HTTP-family intent handling below
semantic family kits.

Current status:

- active as a separate Mix project that depends on root `execution_plane`
- implements the lane-adapter boundary for unary HTTP request/response
  execution
- owns HTTP mechanics only; provider semantics stay in Pristine or other
  family kits
- does not pull `erlexec` or process-lane dependencies
