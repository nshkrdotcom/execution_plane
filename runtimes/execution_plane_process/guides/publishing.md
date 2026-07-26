# Publishing

Publish `execution_plane 0.2.0` first. The historical `execution_plane 0.1.0`
package is a monolith containing these same process modules and will fail a
warnings-as-errors consumer compile with module redefinitions.

Before publishing the package:

1. Verify Hex resolves `execution_plane 0.2.0`, never `0.1.0`.
2. From a clean standalone checkout/package extraction with no sibling core
   path, run `mix deps.get` and `mix compile --warnings-as-errors`.
3. Run `mix ci`.
4. Run `mix hex.build`.
5. Inspect the package manifest and confirm the `execution_plane` requirement
   is `~> 0.2.0`.
6. In the authorized release phase, run `mix hex.publish --yes`.
7. Create the lightweight tag `execution_plane_process-v0.1.0`, push it, and
   verify the remote tag

This monorepo already uses the plain `v0.1.0` tag for the generated
`execution_plane` distribution. Component-qualified tags are therefore
required so a component release identifies its actual source commit without
moving or colliding with that published tag.

The package manifest should include `README.md`, `CHANGELOG.md`, `LICENSE`,
`assets/`, `guides/`, `lib/`, `.formatter.exs`, and `mix.exs`.
