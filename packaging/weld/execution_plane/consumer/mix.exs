defmodule ExecutionPlaneReleaseConsumer.MixProject do
  use Mix.Project

  @repo_root Path.expand("../../../..", __DIR__)
  @ground_plane_root Path.expand("../ground_plane", @repo_root)

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
      {:ground_plane_contracts,
       path: Path.join(@ground_plane_root, "core/ground_plane_contracts"), override: true},
      {:ground_plane_persistence_policy,
       path: Path.join(@ground_plane_root, "core/persistence_policy"), override: true}
    ]
  end
end
