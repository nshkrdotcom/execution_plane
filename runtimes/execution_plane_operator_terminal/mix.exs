defmodule ExecutionPlane.OperatorTerminal.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/execution_plane"

  def project do
    [
      app: :execution_plane_operator_terminal,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
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
      {:ex_ratatui, "~> 0.7.1"},
      {:credo, "~> 1.7.18", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "main",
      extras: [
        {"README.md", filename: "readme"}
      ]
    ]
  end
end
