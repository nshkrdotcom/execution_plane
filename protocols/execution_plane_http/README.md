# Execution Plane HTTP

<p align="center">
  <img src="assets/execution_plane_http.svg" width="200" height="200" alt="Execution Plane HTTP logo">
</p>

<p align="center">
  <a href="https://github.com/nshkrdotcom/execution_plane"><img alt="GitHub" src="https://img.shields.io/badge/github-nshkrdotcom%2Fexecution_plane-24292f?logo=github"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
</p>

`execution_plane_http` owns the lower unary HTTP lane and lane-adapter
boundary for request/response execution.

## Installation

```elixir
def deps do
  [
    {:execution_plane_http, "~> 0.1.0"}
  ]
end
```

All commands default to the published `execution_plane ~> 0.3.0` core package.
Workspace development can select a local source through the standard
`MIX_WORKSPACE_OPS_BOOTSTRAP` hook. No registry tooling is required.

## Guides

The HexDocs menu includes the guide index, installation notes, usage notes,
and publishing checklist for this package.
