# `core/execution_plane_contracts`

Owns the shared Execution Plane contract packet, failure taxonomy, validators,
and conformance fixtures for lineage continuity.

Current packet status:

- active
- canonical owner of the lower-boundary contract structs
- Wave 5 now enforces opaque credential-handle refs so lower intents carry
  handle-style references instead of raw secret material
- minimal-lane family-specific payload shapes remain provisional until Wave 3
