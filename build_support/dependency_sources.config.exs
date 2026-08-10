%{
  deps: %{
    blitz: %{
      hex: "~> 0.3.0",
      default_order: [:hex],
      publish_order: [:hex]
    },
    execution_plane: %{
      path: "core/execution_plane",
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "core/execution_plane"
      },
      hex: "~> 0.2.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    execution_plane_http: %{
      path: "protocols/execution_plane_http",
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "protocols/execution_plane_http"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    execution_plane_jsonrpc: %{
      path: "protocols/execution_plane_jsonrpc",
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "protocols/execution_plane_jsonrpc"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    execution_plane_node: %{
      path: "runtimes/execution_plane_node",
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "runtimes/execution_plane_node"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    execution_plane_operator_terminal: %{
      path: "runtimes/execution_plane_operator_terminal",
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "runtimes/execution_plane_operator_terminal"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    execution_plane_process: %{
      path: "runtimes/execution_plane_process",
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "runtimes/execution_plane_process"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    execution_plane_sse: %{
      path: "streaming/execution_plane_sse",
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "streaming/execution_plane_sse"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    execution_plane_websocket: %{
      path: "streaming/execution_plane_websocket",
      github: %{
        repo: "nshkrdotcom/execution_plane",
        branch: "main",
        subdir: "streaming/execution_plane_websocket"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    ground_plane_contracts: %{
      path: "../ground_plane/core/ground_plane_contracts",
      github: %{
        repo: "nshkrdotcom/ground_plane",
        branch: "main",
        subdir: "core/ground_plane_contracts"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    ground_plane_persistence_policy: %{
      path: "../ground_plane/core/persistence_policy",
      github: %{
        repo: "nshkrdotcom/ground_plane",
        branch: "main",
        subdir: "core/persistence_policy"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    weld: %{
      hex: "~> 0.8.4",
      default_order: [:hex],
      publish_order: [:hex]
    }
  }
}
