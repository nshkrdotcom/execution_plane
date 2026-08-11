# Changelog

## Unreleased

## 0.3.0 - 2026-08-10

- Make dependency selection independent of whichever repository first loaded
  the shared `DependencySources` module. Source-workspace builds pass the
  Execution Plane repository root explicitly; published-package builds use the
  call-site Hex requirements without reading a consumer's workspace registry.

## 0.2.3 - 2026-08-10

- Make the published package loadable by any consumer. 0.2.1 and 0.2.2 required
  `build_support/dependency_sources.exs` from a path outside the tarball, so
  `mix compile` in a consuming project died while Mix loaded this dependency's
  project. Both are retired.
- `mix.exs` now detects whether it is running inside the workspace checkout.
  In the workspace it resolves siblings through the dependency-source registry
  as before; anywhere else it declares plain Hex requirements and never touches
  `build_support`.

## 0.2.2 - 2026-08-10

- Make the published package self-describing. `mix.exs` resolved its
  dependencies through the workspace dependency-source registry, reading a
  config file two directories above itself — a path that exists in this
  checkout and not inside a published tarball, which does not ship
  `build_support/`. Any consumer resolving `execution_plane` from Hex failed
  while Mix loaded the dependency's project. 0.2.1 shipped with this defect.
- Dependency source resolution now treats an absent registry as the ordinary
  state of a published package rather than a missing file, and falls back to
  the `hex:` requirement stated at the call site. Local development still
  resolves siblings by path, unchanged.

## 0.2.1 - 2026-08-10

- Remove two unreachable `normalize_atomish/1` heads in
  `ExecutionPlane.Placements.Capabilities`. The function is only ever reached
  from the `is_binary` branch of `fetch_member/4`, so its atom and catch-all
  clauses were dead code the compiler had already proved unreachable. No
  behavioural change.

## 0.2.0 - 2026-07-27

- Publish `execution_plane` as the common core-only substrate; JSON-RPC and
  process runtime ownership now lives exclusively in their component packages.
- Add the admitted interactive runtime lifecycle contracts, bounded runtime
  errors and status/events, attach and input envelopes, and their boundary
  codecs.
- Replace the former execute/stream runtime-client callbacks with the
  start/subscribe/input/status/cancel lifecycle.

## 0.1.0 - 2026-07-14

Initial release.
