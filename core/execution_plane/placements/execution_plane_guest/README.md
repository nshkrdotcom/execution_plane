# `placements/execution_plane_guest`

Owns guest-backed placement semantics for already-available guest runtimes that
expose the shared bridge protocol.

Wave 7 status:

- active for bridge-backed guest placement
- models guest path semantics separately from generic SSH-style remoting
- does not claim stronger isolation than the actual guest backend provides
- keeps durable attachability and lease meaning above this lower substrate
