# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Make dependency selection collision-proof in parent Mix graphs: source
  checkouts resolve against the Execution Plane registry explicitly, while a
  packaged project uses its declared Hex requirements directly.

## [0.1.2] - 2026-08-10

### Fixed

- Make the published package loadable by any consumer. 0.1.1 required
  `build_support/dependency_sources.exs` from a path outside the tarball, so
  `mix compile` in a consuming project died while Mix loaded this dependency's
  project. 0.1.1 is retired.
- `mix.exs` now detects whether it is running inside the workspace checkout: in
  the workspace it resolves siblings through the dependency-source registry, and
  anywhere else it declares plain Hex requirements.

## [0.1.1] - 2026-08-10

### Fixed

- `ExecutionPlane.Process.Transport.Surface.capabilities/1` guarded its `with`
  clause on `is_atom/1` alone. `nil` is an atom, so a missing `surface_kind`
  satisfied the guard and was forwarded to the adapter registry, which reported
  `{:unsupported_surface_kind, nil}` instead of the
  `{:invalid_execution_surface, opts}` the function defines for that case. The
  same shape made the function's own `nil ->` clause unreachable.
- The guest bridge frame decoder read `length` from outside a bitstring match
  without pinning it. That works on current Elixir, is a hard error on newer
  releases, and reads ambiguously against `Kernel.length/1`.

### Removed

- Dead code the compiler had proved unreachable: two `chunk || ""` fallbacks
  where `decode_bytes/1` always returns a binary on that path, a
  `normalize_env_value/1` boolean clause already covered by the atom clause
  above it, and a `keyword_list?/1` catch-all whose callers all guard on
  `is_list/1`.

## [0.1.0] - 2026-07-27

### Added

- Initial release.
