[
  workspace: [
    root: "..",
    project_globs: ["core/*", "protocols/*", "runtimes/*", "streaming/*"]
  ],
  dependencies: [
    ground_plane_contracts: [requirement: "~> 0.1.0", opts: []],
    ground_plane_persistence_policy: [requirement: "~> 0.1.0", opts: []]
  ],
  classify: [
    tooling: ["."]
  ],
  publication: [
    separate: [
      "protocols/execution_plane_http",
      "streaming/execution_plane_sse",
      "streaming/execution_plane_websocket",
      "runtimes/execution_plane_node",
      "runtimes/execution_plane_operator_terminal"
    ]
  ],
  artifacts: [
    execution_plane: [
      mode: :monolith,
      roots: [
        "core/execution_plane",
        "protocols/execution_plane_jsonrpc",
        "runtimes/execution_plane_process"
      ],
      monolith_opts: [
        shared_test_configs: ["core/execution_plane"]
      ],
      package: [
        name: "execution_plane",
        otp_app: :execution_plane,
        version: "0.1.0",
        elixir: "~> 1.18",
        description: "Execution Plane contracts, JSON-RPC, and process runtime",
        licenses: ["MIT"],
        maintainers: ["nshkrdotcom"],
        links: %{"GitHub" => "https://github.com/nshkrdotcom/execution_plane"},
        docs_main: "readme"
      ],
      output: [
        docs: ["README.md", "guides/index.md"],
        assets: ["CHANGELOG.md", "LICENSE"]
      ],
      verify: [hex_build: false, hex_publish: false]
    ]
  ]
]
