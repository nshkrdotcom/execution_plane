# ADR-008: Provider SDKs Keep Provider Semantics And Drop Runtime Ownership

## Decision

These repos keep provider semantics and drop lower runtime ownership:

- `/home/home/p/g/n/codex_sdk`
- `/home/home/p/g/n/claude_agent_sdk`
- `/home/home/p/g/n/gemini_cli_sdk`
- `/home/home/p/g/n/amp_sdk`
- `/home/home/p/g/n/notion_sdk`
- `/home/home/p/g/n/github_ex`
- `/home/home/p/g/n/linear_sdk`

## Rationale

The provider repos are valuable as semantic surfaces.

They are not the right home for the unified Execution Plane substrate, and they must not leak that lower substrate as their new public API.
