# `runtimes/execution_plane_process`

Owns process launch, stdio, PTY, and long-lived process-session mechanics below
family kits.

Closed-wave status:

- active for one-shot local process execution
- active for `ExecutionPlane.Process.Transport` as the Execution Plane-owned
  long-lived process/session seam
- active tagged-only mailbox delivery for long-lived transport subscribers:
  `subscribe/2` tags by subscriber pid and `subscribe/3` tags by explicit
  reference
- local PTY/stdin attach, lease-aware transport metadata, and session lifecycle
  now flow through that lower transport surface
- the same transport substrate is exercised under local, SSH, and guest
  placement adapters without moving service-runtime semantics into this repo

Operator-facing terminal hosting is not owned here. That lane now lives in the
separate `runtimes/execution_plane_operator_terminal` package so base process
consumers do not inherit `ex_ratatui`.
