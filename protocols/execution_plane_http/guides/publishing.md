# Publishing

This directory publishes `execution_plane_http 0.2.0`; the repository root is
not a package. The package continues to depend on the published
`execution_plane ~> 0.3.0` core and does not require a core API change for the
cancelable unary lifecycle.

Before publication, prove the physical-cancellation acceptance test and the
complete package gate in a checkout with the repository toolchain:

```bash
mix deps.get
mix ci
mix hex.publish --dry-run
```

Then run the root workspace gate:

```bash
cd ../..
mix ci
```

Normal commands and publication default to Hex dependencies. The optional
workspace bootstrap can select local sources explicitly; it is not required.

Hex release state checked on 2026-09-17: the latest published HTTP package is
0.1.0; 0.2.0 is the next release. Publish this package before Pristine 0.4.0.
Use the package-qualified tag `execution_plane_http-v0.2.0` when cutting the
release; repository-wide `v*` tags do not identify this poncho package.
Publication and tagging are separate release actions after QC.

Package contents include README, changelog, license, assets, guides, library
source, formatter configuration, and `mix.exs`.
