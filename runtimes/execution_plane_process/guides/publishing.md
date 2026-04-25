# Publishing

Before publishing the package:

1. Run `mix format`
2. Run `mix test`
3. Run `mix docs --warnings-as-errors`
4. Run `mix hex.build`
5. Run `mix hex.publish`

The package manifest should include `README.md`, `CHANGELOG.md`, `LICENSE`,
`assets/`, `guides/`, `lib/`, `.formatter.exs`, and `mix.exs`.
