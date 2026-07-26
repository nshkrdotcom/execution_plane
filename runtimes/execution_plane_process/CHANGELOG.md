# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-25

### Added

- Initial release.
- `ExecutionPlane.Process`, the `process` lane adapter. It declares the
  `local_subprocess`, `ssh_exec`, and `guest_bridge` execution surfaces, emits
  `ProcessExecutionIntent.v1`, resolves the minimal local process route, and
  executes through `ExecutionPlane.Kernel`.
- `ExecutionPlane.Runtimes.Process`, the one-shot local execution runtime, with
  bounded start, stop, and kill waits taken over a replaceable OS boundary
  behaviour (privileged-user detection, bounded await, and process-group
  signalling).
- `ExecutionPlane.Process.Transport`, the transport behaviour and its surfaces:
  an `:erlexec`-backed `Subprocess` transport with line framing, a long-line
  spool, request tracking, signal control, and subscriber registration;
  `SSHExec` for remote command execution; `GuestBridge` for request/response
  guest protocols; and `LowerSimulation`, which replays configured
  stdout/stderr/exit frames through the same transport contract without ever
  spawning a process.
- `ExecutionPlane.Process.Transport.Surface`, the narrow `execution_surface.v1`
  contract, with per-surface capability declarations and a surface registry.
  Provider family, command selection, and launch arguments stay out of it.
- `ExecutionPlane.ProcessExit`, normalized exit information (`status`, `code`,
  `signal`, `reason`, `stderr`), including the shifted `code * 256` statuses
  some platforms report.
- `ExecutionPlane.Process.TreRhai`, the local TRE/Rhai lane for invoking
  `rex-runner` from a governed envelope of refs and hashes. It materializes
  script and policy material explicitly, writes a bounded runner workspace,
  invokes the runner with a cleared environment, and returns a structured
  receipt; raw policy or script material in the public envelope is rejected.
- A governed env boundary. Process intents identified by authority, lease,
  credential-handle, permission-decision, route-template, attach-grant, or
  target-descriptor refs default `clear_env` to `true` and never populate
  `env_projection` from ambient process environment. Standalone callers keep
  explicit `env` and `clear_env` options.
- Bounded supervisor readiness. The `:execution_plane_process` application
  starts the named task and process-transport supervisors, and runtime library
  calls return `{:error, {:runtime_not_started, :execution_plane_process}}`
  instead of starting a component application themselves.
- Package documentation: overview, guide index, installation, usage, and
  publishing guides.
