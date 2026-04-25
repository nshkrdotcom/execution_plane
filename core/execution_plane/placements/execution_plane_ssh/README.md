# `placements/execution_plane_ssh`

Owns SSH-backed placement semantics below higher family kits and above the
process transport substrate.

Wave 7 status:

- active for truthful remote-shell placement
- models remote path semantics and adapter capabilities without turning SSH into
  a stronger sandbox claim than it is
- keeps service-runtime readiness, health, and lease meaning above this layer
