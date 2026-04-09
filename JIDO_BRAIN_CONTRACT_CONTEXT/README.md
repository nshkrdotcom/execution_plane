# Jido Brain Contract Context

## Why This Exists

`jido_os` is still the architectural Brain in this packet.

It is also intentionally out of execution scope here because the repo is being rebuilt separately.

This directory preserves the Brain-side contract assumptions that the rest of the packet is allowed to depend on without patching `jido_os`.

## Status

- normative for this packet's execution program
- not a substitute for the future `jido_os` source of truth
- expected to be revisited when the Brain rebuild becomes real code

## Packet Rule

- Wave 1, Wave 5, and Wave 6 must read this directory as part of their Brain-side context
- no prompt in this packet may patch `jido_os`
- if a Brain-side mismatch is discovered, update this directory only when the packet snapshot itself is unclear
- if the required fix is an actual `jido_os` code or repo change, record a blocker or rebuild follow-up instead of touching that repo

## Contents

- `01_authority_decision_v1_packet_baseline.md`
- `02_rebuild_handoff.md`
