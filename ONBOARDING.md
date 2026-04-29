# execution_plane Onboarding

Read `AGENTS.md` first; it describes the workspace/package split.
`CLAUDE.md` must stay a one-line compatibility shim containing `@AGENTS.md`.

## Owns

Lower runtime packets and lanes: execution requests/results/events, transport,
placement, target attestations, sandbox profile carriage, and lane adapters.

## Does Not Own

Governance decisions, semantic reasoning, product flows, provider fallback
ladders, or durable business truth.

## First Task

```bash
cd /home/home/p/g/n/execution_plane
mix ci
cd /home/home/p/g/n/stack_lab
mix gn_ten.plan --repo execution_plane
```

## Proofs

StackLab owns assembled proof. Use `/home/home/p/g/n/stack_lab/proof_matrix.yml`
and `/home/home/p/g/n/stack_lab/docs/gn_ten_proof_matrix.md`.

## Common Changes

Keep root tooling separate from publishable packages. Add lane-local tests for
lane changes and root `mix ci` before making substrate claims.
