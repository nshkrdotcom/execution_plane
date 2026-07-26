# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-25

### Added

- Initial release.
- `ExecutionPlane.JsonRpc`, the `jsonrpc` lane adapter. It declares the
  `framing` surface, supports both execute and stream, emits
  `JsonRpcExecutionIntent.v1`, resolves the local process target used for the
  request/response exchange, and executes through `ExecutionPlane.Kernel`.
- `ExecutionPlane.Protocols.JsonRpc`, the minimal framing support used by a
  direct lower-lane owner that depends on both the JSON-RPC and process lanes.
  It defaults `jsonrpc` to `"2.0"` and the request `id` to the envelope's
  attempt ref rather than inventing correlation state.
- `ExecutionPlane.Protocols.JsonRpc.Adapter`, the canonical newline-delimited
  request/response framing and correlation state for persistent lanes:
  - monotonic request-id assignment from a configurable start;
  - `encode_request/2` and `encode_notification/2`, which reject a message
    without a binary `method`;
  - `handle_inbound/2` classification into `{:peer_request, id, message}`,
    `{:response, id, {:ok, result}}`, `{:response, id, {:error, error}}`, and
    `{:notification, message}`, with unparseable input surfaced as a
    `{:protocol_error, _}` event rather than a crash;
  - `encode_peer_reply/3` for bidirectional lanes where the peer calls back;
  - an optional `ready_matcher` that emits a `{:ready, message}` event ahead of
    the classified message;
  - error normalization into a JSON-RPC error object with `code`, `message`,
    and optional `data`, covering handler timeouts, handler exits, handler
    start failures, and unsupported peer requests (`-32601`).
- Package documentation: overview, guide index, installation, usage, and
  publishing guides.
