# Changelog

## 0.2.0 - 2026-07-25

- Publish `execution_plane` as the common core-only substrate; JSON-RPC and
  process runtime ownership now lives exclusively in their component packages.
- Add the admitted interactive runtime lifecycle contracts, bounded runtime
  errors and status/events, attach and input envelopes, and their boundary
  codecs.
- Replace the former execute/stream runtime-client callbacks with the
  start/subscribe/input/status/cancel lifecycle.

## 0.1.0 - 2026-07-14

Initial release.
