defmodule ExecutionPlaneProcess.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/execution_plane"
  @contracts_version "~> 0.1.0"
  @kernel_version "~> 0.1.0"
  @local_version "~> 0.1.0"

  def project do
    [
      app: :execution_plane_process,
      name: "ExecutionPlaneProcess",
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: "Execution Plane process launch, stdio, PTY, and process-session runtime.",
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
      execution_plane_contracts_dep(),
      execution_plane_kernel_dep(),
      execution_plane_local_dep(),
      {:erlexec, "~> 2.3"},
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

  defp execution_plane_local_dep do
    case workspace_dep_path("../../placements/execution_plane_local") do
      nil -> {:execution_plane_local, @local_version}
      path -> {:execution_plane_local, path: path}
    end
  end

  defp workspace_dep_path(relative_path) do
    if prefer_workspace_paths?() do
      path = Path.expand(relative_path, __DIR__)
      if File.dir?(path), do: path
    end
  end

  defp prefer_workspace_paths? do
    workspace_paths_forced?() or
      (not release_deps_forced?() and not Enum.member?(Path.split(__DIR__), "deps"))
  end

  defp release_deps_forced? do
    force_hex_deps?() or Enum.any?(System.argv(), &(&1 in ["hex.build", "hex.publish"]))
  end

  defp workspace_paths_forced? do
    not force_hex_deps?() and
      System.get_env("FORCE_WORKSPACE_PATH_DEPS") in ["1", "true", "TRUE", "yes", "YES"]
  end

  defp force_hex_deps? do
    System.get_env("EXECUTION_PLANE_HEX_DEPS") in ["1", "true", "TRUE", "yes", "YES"]
  end

  defp package do
    [
      name: "execution_plane_process",
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
