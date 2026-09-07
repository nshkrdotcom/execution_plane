# Publishing

Publish `ground_plane_contracts 0.1.1` first and verify the already-published
`execution_plane 0.3.0`. The historical `execution_plane 0.1.0`
package is a monolith containing these same process modules and will fail a
warnings-as-errors consumer compile with module redefinitions.

Before publishing the package:

1. Verify Hex resolves `execution_plane 0.3.0`, never `0.1.0`.
2. From a clean standalone checkout/package extraction with no sibling core
   path, run `mix deps.get` and `mix compile --warnings-as-errors`.
3. Run `mix ci`.
4. Run `mix hex.build`.
5. Inspect the package manifest and confirm the `execution_plane` requirement
   is `~> 0.3.0`.
6. In the authorized release phase, run `mix hex.publish --yes`.
7. Create the lightweight tag `v0.3.1`, push it, and
   verify the remote tag.

This release uses the unoccupied plain `v0.3.1` tag. The monorepo's existing
plain `v0.3.0` tag belongs to core history and must not be moved. Recheck tag
availability immediately before publication; never overwrite a remote tag.

The package manifest should include `README.md`, `CHANGELOG.md`, `LICENSE`,
`assets/`, `guides/`, `lib/`, `.formatter.exs`, and `mix.exs`.
