# Node Guide Index

`execution_plane_node` publishes a small HexDocs navigation set for the
package root.

- [Installation](installation.md)
- [Usage](usage.md)
- [Publishing](publishing.md)

This package hosts governed admission and one-shot node dispatch through
`ExecutionPlane.Node.Client`. Lane selection remains in the host that
registers the adapters and verifiers. The separate interactive
`ExecutionPlane.Runtime.Client` contract is not implemented here.
