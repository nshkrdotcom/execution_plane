if bootstrap = System.get_env("MIX_WORKSPACE_OPS_BOOTSTRAP"), do: Code.require_file(bootstrap)

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
      workspace_dep({:ground_plane_contracts, "~> 0.1.0", override: true}),
      workspace_dep({:ground_plane_persistence_policy, "~> 0.1.0", override: true})
    ]
  end

  defp workspace_dep(committed) do
    if function_exported?(MixWorkspaceOpsBootstrap, :dep, 2),
      do: apply(MixWorkspaceOpsBootstrap, :dep, [committed, @repo_root]),
      else: committed
  end
end
