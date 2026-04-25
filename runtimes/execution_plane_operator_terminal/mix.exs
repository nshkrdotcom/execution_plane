defmodule ExecutionPlane.OperatorTerminal.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/execution_plane"

  def project do
    [
      app: :execution_plane_operator_terminal,
      name: "ExecutionPlaneOperatorTerminal",
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      dialyzer: dialyzer(),
      aliases: aliases(),
      description:
        "Execution Plane operator-terminal ingress family for local, SSH, and distributed operator-facing TUIs"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ExecutionPlane.OperatorTerminal.Application, []}
    ]
  end

  def cli do
    [preferred_envs: [credo: :test, dialyzer: :dev, docs: :dev]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:ex_ratatui, "~> 0.8.0"},
      {:credo, "~> 1.7.18", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "main",
      source_url: @source_url,
      extras: [
        {"README.md", title: "Overview", filename: "readme"},
        {"CHANGELOG.md", title: "Changelog", filename: "changelog"},
        {"LICENSE", title: "License", filename: "license"},
        {"guides/index.md", title: "Guide Index", filename: "guides_index"},
        {"guides/installation.md", title: "Installation", filename: "installation"},
        {"guides/usage.md", title: "Usage", filename: "usage"},
        {"guides/publishing.md", title: "Publishing", filename: "publishing"}
      ],
      logo: "assets/execution_plane_operator_terminal.svg",
      assets: %{"assets" => "assets"},
      groups_for_extras: [
        Package: ["README.md", "CHANGELOG.md", "LICENSE"],
        Guides: [
          "guides/index.md",
          "guides/installation.md",
          "guides/usage.md",
          "guides/publishing.md"
        ]
      ]
    ]
  end

  defp package do
    [
      maintainers: ["nshkrdotcom"],
      name: "execution_plane_operator_terminal",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(
        .formatter.exs
        CHANGELOG.md
        LICENSE
        README.md
        assets
        guides
        lib
        mix.exs
      )
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      plt_core_path: "priv/plts/core",
      plt_local_path: "priv/plts",
      flags: [:error_handling, :underspecs]
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
