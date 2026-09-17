# Changelog

## 0.1.0 - 2026-09-16

- Refresh all direct dependency requirements to current stable releases and update
  the complete resolved dependency graph (2026-09-16).

- Initial standalone unary HTTP lane, including direct and runtime-client execution.
- Default to the published `execution_plane ~> 0.3.0` dependency for all Mix tasks.
  Local source substitution uses the standard workspace bootstrap hook.
- Pin chunk sizes in bitstring matches for warning-free compilation.
