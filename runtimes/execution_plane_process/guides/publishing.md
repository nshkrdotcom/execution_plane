# Publishing

Publish `execution_plane 0.3.0` first. The historical `execution_plane 0.1.0`
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
7. Create the lightweight tag `execution_plane_process-v0.3.0`, push it, and
   verify the remote tag.

This monorepo already uses plain `v*` tags for the core package. Process tags
therefore use the package-qualified `execution_plane_process-v0.3.0` form;
the plain `v0.3.0` tag is already core history.

The package manifest should include `README.md`, `CHANGELOG.md`, `LICENSE`,
`assets/`, `guides/`, `lib/`, `.formatter.exs`, and `mix.exs`.
