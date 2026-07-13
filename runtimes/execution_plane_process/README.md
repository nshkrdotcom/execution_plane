# Execution Plane Process

<p align="center">
  <img src="assets/execution_plane_process.svg" width="200" height="200" alt="Execution Plane Process logo">
</p>

<p align="center">
  <a href="https://github.com/nshkrdotcom/execution_plane"><img alt="GitHub" src="https://img.shields.io/badge/github-nshkrdotcom%2Fexecution_plane-24292f?logo=github"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
</p>

`execution_plane_process` owns process launch, stdio, PTY, and long-lived
process-session mechanics below family kits.

## Governed Env Boundary

Standalone callers may pass explicit `env` and `clear_env` options as before.
Governed process intents, identified by authority, lease, credential, route
template, attach grant, or target descriptor refs, default `clear_env` to
`true` and never populate `env_projection` from ambient process env. Lease or
authority materializers must pass any required process env as explicit
`env_projection` input for that one effect.

## Runtime Supervision

The standalone `:execution_plane_process` application starts the named task
and process-transport supervisors. The welded `:execution_plane` distribution
starts the same named supervisors from its generated application.
Runtime library calls check those supervisors directly and return
`{:error, {:runtime_not_started, :execution_plane_process}}` when they are
absent; they never try to start a component application.

The subprocess launcher still calls `Application.ensure_all_started(:erlexec)`.
That is intentional: `:erlexec` is a real external OTP dependency whose worker
must be available before operating-system process launch.

## Installation

```elixir
def deps do
  [
    {:execution_plane_process, "~> 0.1.0"}
  ]
end
```

## Guides

The HexDocs menu includes the guide index, installation notes, usage notes,
and publishing checklist for this package.
