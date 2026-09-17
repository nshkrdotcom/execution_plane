# Execution Plane HTTP 0.2.0 release readiness

Verified 2026-09-17 on Erlang 28.3.1 / Elixir 1.19.5-otp-28.

- Focused real TCP cancellation acceptance: passed, including normal completion,
  cancellation from another process, owner death, invalid method preflight,
  wait-timeout cleanup, worker termination, and no leftover terminal messages.
- Active adapter, runtime-client gateway, and package regressions: passed.
- Package `mix ci`: passed (15 tests, formatter, warnings-as-errors compilation,
  strict Credo, Dialyzer, and warnings-as-errors docs).
- Root `mix ci`: passed; dependency bootstrap ran for all eight projects and
  impact CI selected HTTP and the reverse-dependent runtime node.
- `mix hex.build --unpack` and `mix hex.publish --dry-run --yes`: passed.
- Unpacked artifact `mix deps.get` and `mix compile --warnings-as-errors`: passed
  against published Hex core 0.3.0, without a workspace source overlay.

Hex's latest HTTP release was 0.1.0 when checked. Publish HTTP 0.2.0 before
Pristine 0.4.0. The future tag is `execution_plane_http-v0.2.0`.
No publication or tag was performed during preparation.

Unary transport is OTP `:httpc` with HTTP/1.1 socket cancellation evidence.
Cancellation is not remote rollback or exactly-once execution; an already
completed response may win the race. Reasons remain lifecycle metadata.
