unless Code.ensure_loaded?(DependencySources) do
  Code.require_file("../../build_support/dependency_sources.exs", __DIR__)
end

defmodule ExecutionPlane.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/nshkrdotcom/execution_plane"
  @homepage_url "https://hex.pm/packages/execution_plane"
  @docs_url "https://hexdocs.pm/execution_plane"
  @repo_root Path.expand("../..", __DIR__)
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
      source_url: @source_url,
      homepage_url: @homepage_url,
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

  defp elixirc_paths(:test), do: ["lib"]

  defp elixirc_paths(_env), do: ["lib"]

  defp test_paths do
    [
      "test/core",
      "test/placements"
    ]
  end

  defp deps do
    [
      DependencySources.dep(:ground_plane_contracts, @repo_root),
      DependencySources.dep(:ground_plane_persistence_policy, @repo_root),
      {:jason, "~> 1.4.5"},
      {:telemetry, "~> 1.4.2"},
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.3", only: :dev, runtime: false}
    ]
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
      source_ref: "v#{@version}",
      source_url: @source_url,
      source_url_pattern:
        "#{@source_url}/blob/v#{@version}/core/execution_plane/%{path}#L%{line}",
      homepage_url: @docs_url
    ]
  end

  defp package do
    [
      maintainers: ["nshkrdotcom"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Hex" => @homepage_url,
        "HexDocs" => @docs_url,
        "Changelog" => "#{@source_url}/blob/main/core/execution_plane/CHANGELOG.md",
        "License" => "#{@source_url}/blob/main/core/execution_plane/LICENSE"
      },
      files: ~w(
          .formatter.exs
          CHANGELOG.md
          LICENSE
          README.md
          assets/execution_plane.svg
          conformance/execution_plane_testkit/README.md
          core/execution_plane_contracts/.formatter.exs
          core/execution_plane_contracts/README.md
          core/execution_plane_kernel/.formatter.exs
          core/execution_plane_kernel/README.md
          guides/index.md
          lib
          mix.exs
          placements/execution_plane_guest/README.md
          placements/execution_plane_local/.formatter.exs
          placements/execution_plane_local/README.md
          placements/execution_plane_ssh/README.md
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
