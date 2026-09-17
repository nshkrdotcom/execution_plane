# Publishing

This directory publishes `execution_plane_http 0.1.0`; the repository root is
not a package. Its `execution_plane ~> 0.3.0` prerequisite is already published
and resolves to 0.3.0. No new core release is needed.

```bash
mix deps.get
mix ci
mix hex.publish --dry-run
mix hex.publish --replace
```

Normal commands and publication both default to Hex dependencies. The optional
workspace bootstrap can select local sources explicitly; it is not required.

The release has been tested with published core 0.3.0. Publish this HTTP package
before the Pristine 0.3.0 runtime, then TypeSafeSDK 0.1.0. No other Execution Plane
lanes, Pristine Codegen, or Pristine Testkit are needed for that runtime chain.

Package contents include README, changelog, license, assets, guides, library
source, formatter configuration, and `mix.exs`.

The owner already uploaded 0.1.0 before this dependency refresh. Use `--replace`
within Hex's replacement window for this prepared revision.
