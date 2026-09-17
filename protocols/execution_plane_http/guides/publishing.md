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

Version 0.2.0 adds public cancelable unary APIs. Before publishing, re-check the
actual Hex package state as required by the repository `AGENTS.md`. The package
changelog in this snapshot records `0.1.0` on 2026-09-16, while older repository
release notes predate that state, so publication history must be confirmed rather
than inferred from either file. Do not publish 0.2.0 until the preceding release
state is reconciled. In all cases, require the real socket-cancellation test and
package/root gates to be green first.

Package contents include README, changelog, license, assets, guides, library
source, formatter configuration, and `mix.exs`.
