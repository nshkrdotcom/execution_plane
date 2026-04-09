# ADR-005: `prismatic` Remains GraphQL Semantics Above HTTP

## Decision

`/home/home/p/g/n/prismatic` stays a GraphQL semantic layer above `/home/home/p/g/n/pristine`.

It must not become a lower runtime or transport repo and must converge on the same lower HTTP execution substrate as the rest of the stack.

## Rationale

GraphQL is a semantic/document layer, not a transport family.
