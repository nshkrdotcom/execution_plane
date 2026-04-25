# Usage

The main helpers are `ExecutionPlane.OperatorTerminal.start/1`,
`start_link/1`, `info/1`, `list/0`, and `stop/1`.

```elixir
{:ok, pid} =
  ExecutionPlane.OperatorTerminal.start(
    mod: MyApp.OperatorTerminal,
    surface_kind: :local_terminal
  )
```

The package models operator-facing TUI ingress and inspection, not workload
execution.
