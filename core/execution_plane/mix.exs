defmodule ExecutionPlane.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/execution_plane"
  @ground_plane_contracts_version "~> 0.1.0"
  @ground_plane_contracts_source [
    github: "nshkrdotcom/ground_plane",
    branch: "main",
    subdir: "core/ground_plane_contracts"
  ]
  @ground_plane_persistence_policy_version "~> 0.1.0"
  @ground_plane_persistence_policy_source [
    github: "nshkrdotcom/ground_plane",
    branch: "main",
    subdir: "core/persistence_policy"
  ]
  @description """
  Execution Plane provides shared lower-runtime contracts, behaviours,
  codecs, placement descriptors, and pure helpers for Execution Plane lane
  adapters, node hosts, and runtime family kits.
  """

  def project do
    [
      app: :execution_plane,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(),
      test_helper: "test/test_helper.exs",
      start_permanent: Mix.env() == :prod,
      description: @description,
      aliases: aliases(),
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    []
  end

  defp elixirc_paths(:test) do
    [
      "lib",
      "core/execution_plane_contracts/lib",
      "core/execution_plane_kernel/lib",
      "placements/execution_plane_local/lib",
      "placements/execution_plane_ssh/lib",
      "placements/execution_plane_guest/lib",
      "conformance/execution_plane_testkit/lib"
    ]
  end

  defp elixirc_paths(_env) do
    [
      "lib",
      "core/execution_plane_contracts/lib",
      "core/execution_plane_kernel/lib",
      "placements/execution_plane_local/lib",
      "placements/execution_plane_ssh/lib",
      "placements/execution_plane_guest/lib"
    ]
  end

  defp test_paths do
    [
      "test/core",
      "test/placements"
    ]
  end

  defp deps do
    [
      ground_plane_contracts_dep(),
      ground_plane_persistence_policy_dep(),
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.3"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp ground_plane_contracts_dep do
    case workspace_dep_path("../../../ground_plane/core/ground_plane_contracts") do
      nil -> external_ground_plane_contracts_dep()
      path -> {:ground_plane_contracts, path: path}
    end
  end

  defp external_ground_plane_contracts_dep do
    if hex_packaging_task?() do
      {:ground_plane_contracts, @ground_plane_contracts_version}
    else
      {:ground_plane_contracts, @ground_plane_contracts_source}
    end
  end

  defp ground_plane_persistence_policy_dep do
    case workspace_dep_path("../../../ground_plane/core/persistence_policy") do
      nil -> external_ground_plane_persistence_policy_dep()
      path -> {:ground_plane_persistence_policy, path: path}
    end
  end

  defp external_ground_plane_persistence_policy_dep do
    if hex_packaging_task?() do
      {:ground_plane_persistence_policy, @ground_plane_persistence_policy_version}
    else
      {:ground_plane_persistence_policy, @ground_plane_persistence_policy_source}
    end
  end

  defp workspace_dep_path(relative_path) do
    if local_workspace_deps?() do
      path = Path.expand(relative_path, __DIR__)
      if File.dir?(path), do: path
    end
  end

  defp local_workspace_deps? do
    not hex_packaging_task?() and not Enum.member?(Path.split(__DIR__), "deps")
  end

  defp hex_packaging_task? do
    Enum.any?(System.argv(), &(&1 in ["hex.build", "hex.publish"]))
  end

  defp docs do
    [
      main: "readme",
      extras: [
        {"README.md", filename: "readme"},
        {"CHANGELOG.md", filename: "changelog"},
        {"LICENSE", filename: "license"},
        {"guides/index.md", filename: "guides_index"},
        {"technical/02_repo_topology_and_package_map.md", filename: "repo_topology"},
        {"technical/07_brain_spine_and_harness_alignment.md", filename: "brain_spine_alignment"},
        {"core/execution_plane_contracts/README.md", filename: "execution_plane_contracts"},
        {"core/execution_plane_kernel/README.md", filename: "execution_plane_kernel"},
        {"placements/execution_plane_local/README.md", filename: "execution_plane_local"},
        {"placements/execution_plane_ssh/README.md", filename: "execution_plane_ssh"},
        {"placements/execution_plane_guest/README.md", filename: "execution_plane_guest"},
        {"conformance/execution_plane_testkit/README.md", filename: "execution_plane_testkit"}
      ],
      groups_for_extras: [
        Overview: ["README.md", "guides/index.md"],
        Publishing: ["CHANGELOG.md", "LICENSE"],
        Technical: [
          "technical/02_repo_topology_and_package_map.md",
          "technical/07_brain_spine_and_harness_alignment.md"
        ],
        "Package Homes": [
          "core/execution_plane_contracts/README.md",
          "core/execution_plane_kernel/README.md",
          "placements/execution_plane_local/README.md",
          "placements/execution_plane_ssh/README.md",
          "placements/execution_plane_guest/README.md",
          "conformance/execution_plane_testkit/README.md"
        ]
      ],
      assets: %{"assets" => "assets"},
      logo: "assets/execution_plane.svg",
      source_ref: "main",
      source_url: @source_url
    ]
  end

  defp package do
    [
      maintainers: ["nshkrdotcom"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(
          .formatter.exs
          CHANGELOG.md
          LICENSE
          README.md
          assets/execution_plane.svg
          conformance/execution_plane_testkit/README.md
          conformance/execution_plane_testkit/lib
          core/execution_plane_contracts/.formatter.exs
          core/execution_plane_contracts/README.md
          core/execution_plane_contracts/lib
          core/execution_plane_kernel/.formatter.exs
          core/execution_plane_kernel/README.md
          core/execution_plane_kernel/lib
          guides/index.md
          lib
          mix.exs
          placements/execution_plane_guest/README.md
          placements/execution_plane_guest/lib
          placements/execution_plane_local/.formatter.exs
          placements/execution_plane_local/README.md
          placements/execution_plane_local/lib
          placements/execution_plane_ssh/README.md
          placements/execution_plane_ssh/lib
          technical/02_repo_topology_and_package_map.md
          technical/07_brain_spine_and_harness_alignment.md
        )
    ]
  end

  defp aliases do
    [
      ci: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "cmd env MIX_ENV=test mix test",
        "credo --strict",
        "cmd env MIX_ENV=test mix dialyzer --force-check",
        "docs --warnings-as-errors"
      ]
    ]
  end
end
