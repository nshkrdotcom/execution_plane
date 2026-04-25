# Installation

Add the package as a dependency:

```elixir
def deps do
  [
    {:execution_plane_http, "~> 0.1.0"}
  ]
end
```

When developing inside the workspace, use a sibling path dependency. When
publishing to Hex, keep the versioned dependency form and let Hex resolve the
package normally.
