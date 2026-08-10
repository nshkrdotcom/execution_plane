unless Code.ensure_loaded?(DependencySources) do
  Code.require_file("../../../../build_support/dependency_sources.exs", __DIR__)
end

defmodule ExecutionPlaneReleaseConsumer.MixProject do
  use Mix.Project

  @repo_root Path.expand("../../../..", __DIR__)

  def project do
    [
      app: :execution_plane_release_consumer,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: false,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:execution_plane, path: Path.join(@repo_root, "dist/monolith/execution_plane")},
      DependencySources.dep(:ground_plane_contracts, @repo_root, override: true),
      DependencySources.dep(:ground_plane_persistence_policy, @repo_root, override: true)
    ]
  end
end
