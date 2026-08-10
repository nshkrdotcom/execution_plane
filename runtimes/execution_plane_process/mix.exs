unless Code.ensure_loaded?(DependencySources) do
  Code.require_file("../../build_support/dependency_sources.exs", __DIR__)
end

defmodule ExecutionPlaneProcess.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/nshkrdotcom/execution_plane"
  @homepage_url "https://hex.pm/packages/execution_plane_process"
  @docs_url "https://hexdocs.pm/execution_plane_process"

  def project do
    [
      app: :execution_plane_process,
      name: "ExecutionPlaneProcess",
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: "Execution Plane process launch, stdio, PTY, and process-session runtime.",
      source_url: @source_url,
      homepage_url: @homepage_url,
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:crypto, :logger],
      mod: {ExecutionPlane.Process.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      DependencySources.dep(:execution_plane, hex: "~> 0.2.2"),
      DependencySources.dep(:ground_plane_contracts, hex: "~> 0.1.0"),
      {:erlexec, "~> 2.3.4"},
      {:jason, "~> 1.4.5"},
      {:telemetry, "~> 1.4.2"},
      {:ex_doc, "~> 0.40.3", only: :dev, runtime: false},
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["nshkrdotcom"],
      name: "execution_plane_process",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Hex" => @homepage_url,
        "HexDocs" => @docs_url,
        "Changelog" => "#{@source_url}/blob/main/runtimes/execution_plane_process/CHANGELOG.md",
        "License" => "#{@source_url}/blob/main/runtimes/execution_plane_process/LICENSE"
      },
      files: ~w(.formatter.exs CHANGELOG.md LICENSE README.md assets guides lib mix.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "execution_plane_process-v#{@version}",
      source_url: @source_url,
      source_url_pattern:
        "#{@source_url}/blob/execution_plane_process-v#{@version}/runtimes/execution_plane_process/%{path}#L%{line}",
      homepage_url: @docs_url,
      logo: "assets/execution_plane_process.svg",
      assets: %{"assets" => "assets"},
      extras: [
        {"README.md", title: "Overview", filename: "readme"},
        {"CHANGELOG.md", title: "Changelog", filename: "changelog"},
        {"LICENSE", title: "License", filename: "license"},
        {"guides/index.md", title: "Guide Index", filename: "guides_index"},
        {"guides/installation.md", title: "Installation", filename: "installation"},
        {"guides/usage.md", title: "Usage", filename: "usage"},
        {"guides/publishing.md", title: "Publishing", filename: "publishing"}
      ],
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

  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      plt_core_path: "_build/plts/core",
      plt_local_path: "_build/plts",
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
