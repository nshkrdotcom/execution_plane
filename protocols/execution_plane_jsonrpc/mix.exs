defmodule ExecutionPlaneJsonRpc.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/nshkrdotcom/execution_plane"
  @homepage_url "https://hex.pm/packages/execution_plane_jsonrpc"
  @docs_url "https://hexdocs.pm/execution_plane_jsonrpc"
  @execution_plane_version "~> 0.3.0"
  @execution_plane_source [
    github: "nshkrdotcom/execution_plane",
    branch: "main",
    subdir: "core/execution_plane"
  ]

  def project do
    [
      app: :execution_plane_jsonrpc,
      name: "ExecutionPlaneJsonRpc",
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "Execution Plane JSON-RPC framing and correlation lane.",
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
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      execution_plane_dep(),
      {:jason, "~> 1.4.5"},
      {:ex_doc, "~> 0.40.3", only: :dev, runtime: false},
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp execution_plane_dep do
    case workspace_dep_path("../../core/execution_plane") do
      nil -> external_execution_plane_dep()
      path -> {:execution_plane, path: path}
    end
  end

  defp external_execution_plane_dep do
    if hex_packaging_task?() do
      {:execution_plane, @execution_plane_version}
    else
      {:execution_plane, @execution_plane_source}
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
      name: "execution_plane_jsonrpc",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Hex" => @homepage_url,
        "HexDocs" => @docs_url,
        "Changelog" => "#{@source_url}/blob/main/protocols/execution_plane_jsonrpc/CHANGELOG.md",
        "License" => "#{@source_url}/blob/main/protocols/execution_plane_jsonrpc/LICENSE"
      },
      files: ~w(.formatter.exs CHANGELOG.md LICENSE README.md assets guides lib mix.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "execution_plane_jsonrpc-v#{@version}",
      source_url: @source_url,
      source_url_pattern:
        "#{@source_url}/blob/execution_plane_jsonrpc-v#{@version}/protocols/execution_plane_jsonrpc/%{path}#L%{line}",
      homepage_url: @docs_url,
      logo: "assets/execution_plane_jsonrpc.svg",
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
