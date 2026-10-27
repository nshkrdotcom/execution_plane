# Publishing

This checklist publishes `execution_plane_process 0.3.2` after `execution_plane 0.3.1`.
The historical `execution_plane 0.1.0` monolith must never appear in this graph.

1. Resolve dependencies in ordinary Hex mode with the MWO bootstrap unset.
2. Run `mix deps.update --all`, `mix ci`, and `mix hex.build`.
3. Verify a clean standalone package compiles against Hex `execution_plane 0.3.1`.
4. Confirm the package metadata requires `execution_plane ~> 0.3.1` and contains no path or Git dependencies.
5. Commit the reviewed source, then run `mix hex.publish`.
6. Verify the published package and documentation, then tag the exact commit
   `execution_plane_process-v0.3.2` and push the release commit and tag.

Package-specific tags avoid collisions between independent releases in this monorepo.
