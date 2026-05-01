defmodule ExecutionPlane.Workspace.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/execution_plane"

  def project do
    [
      app: :execution_plane_workspace,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      blitz_workspace: blitz_workspace(),
      deps: deps(),
      docs: docs(),
      name: "Execution Plane Workspace",
      description: "Tooling root for the Execution Plane non-umbrella workspace",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [
        ci: :test,
        credo: :test,
        dialyzer: :test
      ]
    ]
  end

  defp deps do
    [
      {:blitz, "~> 0.2.0", runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    monorepo_aliases = [
      "monorepo.deps.get": ["blitz.workspace deps_get"],
      "monorepo.ci": ["blitz.workspace ci"]
    ]

    [
      ci: [
        "format --check-formatted",
        "deps.get",
        "monorepo.deps.get",
        "monorepo.ci"
      ],
      "docs.root": ["docs"]
    ] ++ monorepo_aliases
  end

  defp blitz_workspace do
    [
      root: __DIR__,
      projects: workspace_projects(),
      isolation: [
        deps_path: true,
        build_path: true,
        lockfile: true,
        hex_home: "_build/hex",
        unset_env: ["HEX_API_KEY"]
      ],
      parallelism: [
        env: "EXECUTION_PLANE_WORKSPACE_MAX_CONCURRENCY",
        multiplier: :auto,
        base: [
          deps_get: 4,
          ci: 4
        ],
        overrides: []
      ],
      tasks: [
        deps_get: [args: ["deps.get"], preflight?: false],
        ci: [args: ["ci"], color: true]
      ]
    ]
  end

  defp workspace_projects do
    [
      "core/execution_plane",
      "protocols/execution_plane_http",
      "protocols/execution_plane_jsonrpc",
      "streaming/execution_plane_sse",
      "streaming/execution_plane_websocket",
      "runtimes/execution_plane_process",
      "runtimes/execution_plane_node",
      "runtimes/execution_plane_operator_terminal"
    ]
  end

  defp docs do
    [
      main: "workspace_overview",
      extras: [
        {"README.md", filename: "workspace_overview"},
        "AGENTS.md",
        {"CHANGELOG.md", filename: "changelog"},
        {"LICENSE", filename: "license"},
        {"guides/index.md", filename: "guides_index"},
        {"technical/02_repo_topology_and_package_map.md", filename: "repo_topology"},
        {"technical/07_brain_spine_and_harness_alignment.md", filename: "brain_spine_alignment"},
        {"core/execution_plane/README.md", filename: "execution_plane"},
        {"core/execution_plane/core/execution_plane_contracts/README.md",
         filename: "execution_plane_contracts"},
        {"core/execution_plane/core/execution_plane_kernel/README.md",
         filename: "execution_plane_kernel"},
        {"core/execution_plane/placements/execution_plane_local/README.md",
         filename: "execution_plane_local"},
        {"core/execution_plane/placements/execution_plane_ssh/README.md",
         filename: "execution_plane_ssh"},
        {"core/execution_plane/placements/execution_plane_guest/README.md",
         filename: "execution_plane_guest"},
        {"core/execution_plane/conformance/execution_plane_testkit/README.md",
         filename: "execution_plane_testkit"},
        {"runtimes/execution_plane_node/README.md", filename: "execution_plane_node"},
        {"protocols/execution_plane_http/README.md", filename: "execution_plane_http"},
        {"protocols/execution_plane_jsonrpc/README.md", filename: "execution_plane_jsonrpc"},
        {"streaming/execution_plane_sse/README.md", filename: "execution_plane_sse"},
        {"streaming/execution_plane_websocket/README.md", filename: "execution_plane_websocket"},
        {"runtimes/execution_plane_process/README.md", filename: "execution_plane_process"},
        {"runtimes/execution_plane_operator_terminal/README.md",
         filename: "execution_plane_operator_terminal"}
      ],
      groups_for_extras: [
        Overview: ["README.md", "guides/index.md"],
        Publishing: ["CHANGELOG.md", "LICENSE"],
        Technical: [
          "technical/02_repo_topology_and_package_map.md",
          "technical/07_brain_spine_and_harness_alignment.md"
        ],
        Packages: [
          "core/execution_plane/README.md",
          "runtimes/execution_plane_node/README.md",
          "protocols/execution_plane_http/README.md",
          "protocols/execution_plane_jsonrpc/README.md",
          "streaming/execution_plane_sse/README.md",
          "streaming/execution_plane_websocket/README.md",
          "runtimes/execution_plane_process/README.md",
          "runtimes/execution_plane_operator_terminal/README.md"
        ],
        "Execution Plane Common Homes": [
          "core/execution_plane/core/execution_plane_contracts/README.md",
          "core/execution_plane/core/execution_plane_kernel/README.md",
          "core/execution_plane/placements/execution_plane_local/README.md",
          "core/execution_plane/placements/execution_plane_ssh/README.md",
          "core/execution_plane/placements/execution_plane_guest/README.md",
          "core/execution_plane/conformance/execution_plane_testkit/README.md"
        ]
      ],
      assets: %{"assets" => "assets"},
      logo: "assets/execution_plane.svg",
      source_ref: "main",
      source_url: @source_url
    ]
  end
end
