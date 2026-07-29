# Usage

`ExecutionPlane.Node.LocalClient` retains the package's one-shot compatibility
surface. New interactive consumers use
`ExecutionPlane.Node.DistributedClient`.

```elixir
server = {ExecutionPlane.Node.Server, :"effect@trusted-host"}

{:ok, active} =
  ExecutionPlane.Node.DistributedClient.start(admission_request,
    server: server
  )

:ok =
  ExecutionPlane.Node.DistributedClient.subscribe(
    active.execution_ref,
    self(),
    server: server,
    fence: active.fence
  )
```

Register the lane adapters, target verifiers, evidence sinks, and authority
verifier before admitting governed traffic.

The server tuple is trusted deployment configuration. Never convert incoming
node-name or registered-name strings into atoms. Opaque execution refs cross
the client boundary; worker and lower-transport PIDs do not.
