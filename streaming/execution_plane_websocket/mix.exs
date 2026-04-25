defmodule ExecutionPlaneWebSocket.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/execution_plane"
  @execution_plane_version "~> 0.1.0"

  def project do
    [
      app: :execution_plane_websocket,
      name: "ExecutionPlaneWebSocket",
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "Execution Plane lower WebSocket handshake and frame lifecycle.",
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      execution_plane_dep(),
      {:mint, "~> 1.7"},
      {:mint_web_socket, "~> 1.0"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp execution_plane_dep do
    case workspace_dep_path("../../core/execution_plane") do
      nil -> {:execution_plane, @execution_plane_version}
      path -> {:execution_plane, path: path}
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

  defp package do
    [
      maintainers: ["nshkrdotcom"],
      name: "execution_plane_websocket",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(.formatter.exs CHANGELOG.md LICENSE README.md assets guides lib mix.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "main",
      source_url: @source_url,
      logo: "assets/execution_plane_websocket.svg",
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
