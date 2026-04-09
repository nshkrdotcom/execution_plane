# `runtimes/execution_plane_process`

Owns process launch, stdio, PTY, and long-lived process-session mechanics below
family kits.

Wave 2 status:

- active for basic local one-shot process execution
- attach and reconnect semantics are contract-frozen first, not fully implemented
