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

For workspace development, the package can use a sibling path dependency. For
Hex publishing, the release should resolve from Hex as usual.

## Guides

The HexDocs menu includes the guide index, installation notes, usage notes,
and publishing checklist for this package.
