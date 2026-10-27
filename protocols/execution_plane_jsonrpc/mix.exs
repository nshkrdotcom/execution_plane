if bootstrap = System.get_env("MIX_WORKSPACE_OPS_BOOTSTRAP"), do: Code.require_file(bootstrap)

defmodule ExecutionPlaneJsonRpc.MixProject do
  use Mix.Project

  @version "0.2.1"
  @source_url "https://github.com/nshkrdotcom/execution_plane"
  @homepage_url "https://hex.pm/packages/execution_plane_jsonrpc"
  @docs_url "https://hexdocs.pm/execution_plane_jsonrpc"

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
      {:ex_doc, "~> 0.40.4", only: :dev, runtime: false},
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.8", only: [:dev, :test], runtime: false}
    ]
  end

  defp execution_plane_dep, do: workspace_dep({:execution_plane, "~> 0.3.1"})

  defp workspace_dep(committed) do
    if function_exported?(MixWorkspaceOpsBootstrap, :dep, 2),
      do: apply(MixWorkspaceOpsBootstrap, :dep, [committed, __DIR__]),
      else: committed
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
