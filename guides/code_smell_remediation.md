# Execution Plane Code Smell Remediation

This guide records the repo-local implementation posture after the GN-TEN code
smell remediation pass.

## What Changed

- Subprocess transport state is split so OS command, polling, spooling, and
  GenServer state do not live in one broad module.
- Public starts route through transport supervisors instead of bypassing owner
  supervision.
- OS command execution is kept behind named lower runtime boundaries with
  attestation and evidence.
- File spooling is moved out of transport GenServer state.
- Guest bridge state is narrowed and supervised.

## Maintainer Rules

- Execution Plane owns lower lane contracts, target validation, placement, and
  evidence. It does not own product policy or connector semantics.
- Do not add unsupervised public starts or fallback ladders inside lane hosts.
- Lower command execution must carry explicit target and authority evidence.

## QC

Use the repo root gate:

```bash
mix ci
```
