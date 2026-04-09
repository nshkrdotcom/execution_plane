defmodule ExecutionPlane.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/execution_plane"
  @description """
  Execution Plane is an Elixir/OTP runtime substrate for boundary-aware AI
  infrastructure, unifying process execution, protocol framing, transport
  lifecycle, realtime streams, JSON-RPC control lanes, and future
  sandbox-backed placement under one composable kernel.
  """

  def project do
    [
      app: :execution_plane,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: @description,
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ExecutionPlane.Application, []}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.37", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      logo: "assets/execution_plane.svg",
      source_ref: "main",
      source_url: @source_url
    ]
  end

  defp package do
    [
      maintainers: ["nshkrdotcom"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(.formatter.exs LICENSE README.md assets lib mix.exs)
    ]
  end
end
