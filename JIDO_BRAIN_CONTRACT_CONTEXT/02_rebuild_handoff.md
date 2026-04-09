# Brain Rebuild Handoff

## What The Future `jido_os` Rebuild Must Preserve Or Replace Deliberately

- Brain ownership of authority, trust, approval-policy, boundary, and topology direction
- authored decision contracts that can be carried durably through `jido_integration`
- a clean separation between policy authorship and live runtime mechanics
- stable policy identity for replay, audit, and route linkage
- explicit policy axes for boundary, trust, approval, egress, workspace, and resource handling

## What This Packet Intentionally Does Not Decide

- the internal architecture of the rebuilt Brain
- the Brain's UI, interactive workflow, or sync convenience APIs
- the internal policy compiler or decision engine structure
- any transport, guest bridge, sandbox adapter, or runtime driver implementation

## If The Rebuild Diverges

- update this directory first so packet assumptions are honest
- treat any semantic break as a versioned contract change
- plan the downstream Spine and Execution Plane alignment as a separate migration rather than silently changing the contract mid-packet
