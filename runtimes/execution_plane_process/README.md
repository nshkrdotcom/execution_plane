# `runtimes/execution_plane_process`

Owns process launch, stdio, PTY, and long-lived process-session mechanics below
family kits.

Wave 2 status:

- active for basic local one-shot process execution
- Wave 6 adds `ExecutionPlane.Process.Transport` as the Execution Plane-owned long-lived session seam
- local PTY/stdin attach and session lifecycle now flow through that lower transport surface
