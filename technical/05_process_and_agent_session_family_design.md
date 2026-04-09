# Process And Agent Session Family Design

## End-State Ownership

### Execution Plane process/runtime packages

Packages:

- `/home/home/p/g/n/execution_plane/runtimes/execution_plane_process`
- `/home/home/p/g/n/execution_plane/protocols/execution_plane_jsonrpc`
- relevant placement packages

Own:

- subprocess lifecycle
- stdio / PTY attach behavior
- local / SSH / guest process execution
- lower JSON-RPC framing and correlation
- process-backed session teardown and reconnect mechanics

Do not own:

- CLI semantic planning
- agent-session semantics
- provider-native control semantics

### CLI family kit

Repo:

- `/home/home/p/g/n/cli_subprocess_core`

After refactor it owns:

- provider profiles
- common CLI command/session semantics
- model registry and provider-neutral CLI planning
- projection of `ExecutionEvent.v1` and `ExecutionOutcome.v1` into CLI-facing events

It no longer owns:

- raw process transport mechanics
- the canonical placement substrate
- JSON-RPC framing as a lower runtime primitive

## Provider SDK Roles

### `/home/home/p/g/n/codex_sdk`

Keeps:

- Codex-native semantics
- app-server control semantics
- MCP semantics
- realtime and voice above the common CLI lane where applicable

Moves:

- exec JSONL and app-server subprocess mechanics onto Execution Plane process and JSON-RPC primitives

### `/home/home/p/g/n/claude_agent_sdk`

Keeps:

- Claude-native control family
- hooks, permission callbacks, MCP routing

Moves:

- the common CLI runtime lane onto the Execution Plane-backed `cli_subprocess_core`

### `/home/home/p/g/n/gemini_cli_sdk` and `/home/home/p/g/n/amp_sdk`

Keep:

- provider-specific CLI discovery
- provider-specific event projection

Move:

- all lower process/runtime mechanics onto the shared Execution Plane-backed CLI path

## Session Kernel Role

Repo:

- `/home/home/p/g/n/agent_session_manager`

After refactor it:

- remains the provider-neutral multi-turn session kernel
- consumes `BoundarySessionDescriptor.v1`, `ExecutionRoute.v1`, and `AttachGrant.v1`
- does not own transport families
- does not own provider protocol parsing

## Facade Role

Repo:

- `/home/home/p/g/n/jido_harness`

After refactor it:

- remains a contract and driver facade
- may map execution-plane contracts into public runtime-driver APIs
- must not become a thin public alias for the Execution Plane

## Capability Waves For This Slice

### Minimal viable lane

- basic process launch
- stdio execution
- unary JSON-RPC request/response where needed

### Session-bearing lane

- PTY attach
- long-lived subprocess sessions
- reconnect and resume rules
- JSON-RPC session correlation over persistent lanes

The session-bearing wave closes only when attach/reconnect semantics are tested across the Execution Plane, family kit, and session kernel.
