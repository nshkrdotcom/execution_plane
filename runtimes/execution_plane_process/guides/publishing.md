# Publishing

Before publishing the package:

1. Run `mix format`
2. Run `mix test`
3. Run `mix docs --warnings-as-errors`
4. Run `mix hex.build`
5. In the authorized release phase, run `mix hex.publish --yes`
6. Create the lightweight tag `execution_plane_process-v0.1.0`, push it, and
   verify the remote tag

This monorepo already uses the plain `v0.1.0` tag for the generated
`execution_plane` distribution. Component-qualified tags are therefore
required so a component release identifies its actual source commit without
moving or colliding with that published tag.

The package manifest should include `README.md`, `CHANGELOG.md`, `LICENSE`,
`assets/`, `guides/`, `lib/`, `.formatter.exs`, and `mix.exs`.
