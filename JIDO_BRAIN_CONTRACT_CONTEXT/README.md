# Jido Brain Contract Context

## Purpose

This directory captures the current Brain-side contract context for `citadel` and the durable contract lineage that feeds `jido_integration`.

## Status

- normative for current packet work
- use `citadel`'s `AGENTS.md` and source as current Brain-side truth
- expected to be revisited when contract semantics change

## Packet Rule

- Wave 1, Wave 5, and Wave 6 must read this directory as part of their Brain-side context
- if a Brain-side mismatch is discovered, update this directory only when the packet snapshot itself is unclear
- if the required fix is an actual code or repo change in the Brain or Spine layers, record a blocker or follow-up instead of patching around it

## Contents

- `01_authority_decision_v1_packet_baseline.md`
- `02_rebuild_handoff.md`
