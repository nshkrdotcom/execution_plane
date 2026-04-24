defmodule ExecutionPlaneHttp.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/execution_plane"
  @contracts_version "~> 0.1.0"
  @kernel_version "~> 0.1.0"

  def project do
    [
      app: :execution_plane_http,
      name: "ExecutionPlaneHttp",
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "Execution Plane unary HTTP lower transport and intent helper.",
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:inets, :logger, :ssl]
    ]
  end

  defp deps do
    [
      execution_plane_contracts_dep(),
      execution_plane_kernel_dep(),
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp execution_plane_contracts_dep do
    case workspace_dep_path("../../core/execution_plane_contracts") do
      nil -> {:execution_plane_contracts, @contracts_version}
      path -> {:execution_plane_contracts, path: path}
    end
  end

  defp execution_plane_kernel_dep do
    case workspace_dep_path("../../core/execution_plane_kernel") do
      nil -> {:execution_plane_kernel, @kernel_version}
      path -> {:execution_plane_kernel, path: path}
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
      name: "execution_plane_http",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(.formatter.exs mix.exs README.md lib)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "main",
      source_url: @source_url,
      extras: ["README.md": [title: "Overview", filename: "readme"]]
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
