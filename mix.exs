defmodule ExecutionPlane.MixProject do
  use Mix.Project

  def project do
    [
      app: :execution_plane,
      version: "0.1.0",
      build_path: "_build",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      erlc_paths: [],
      deps: deps(),
      description: "Execution Plane contracts, JSON-RPC, and process runtime",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [mod: {ExecutionPlane.Application, []}, extra_applications: [:crypto, :logger]]
  end

  def elixirc_paths(:test) do
    if File.dir?("test/support") do
      ["lib", "test/support"]
    else
      ["lib"]
    end
  end

  def elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:erlexec, "~> 2.3"},
      {:ground_plane_contracts, "~> 0.1.0"},
      {:ground_plane_persistence_policy, "~> 0.1.0"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.3"},
      {:credo, "~> 1.7", [only: [:dev, :test], runtime: false]},
      {:dialyxir, "~> 1.4", [only: [:dev, :test], runtime: false]},
      {:ex_doc, "~> 0.40", [only: :dev, runtime: false]}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["nshkrdotcom"],
      links: %{"GitHub" => "https://github.com/nshkrdotcom/execution_plane"},
      files: [
        ".formatter.exs",
        "CHANGELOG.md",
        "LICENSE",
        "README.md",
        "assets/execution_plane.svg",
        "config",
        "guides",
        "lib",
        "mix.exs",
        "projection.lock.json"
      ]
    ]
  end

  defp docs do
    [
      groups_for_extras: [
        {"Start Here", ["README.md", "guides/index.md"]},
        {"Guides", ["guides/code_smell_remediation.md"]},
        {"Project", ["CHANGELOG.md", "LICENSE"]}
      ],
      assets: %{"assets" => "assets"},
      source_ref: "v0.1.0",
      source_url: "https://github.com/nshkrdotcom/execution_plane",
      homepage_url: "https://github.com/nshkrdotcom/execution_plane",
      logo: "assets/execution_plane.svg",
      main: "readme",
      extras: [
        {"CHANGELOG.md", [title: "Changelog"]},
        {"LICENSE", [title: "License"]},
        {"README.md", [title: "Overview"]},
        {"guides/code_smell_remediation.md", [title: "Code Smell Remediation"]},
        {"guides/index.md", [title: "Package Guide"]}
      ]
    ]
  end
end
