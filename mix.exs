defmodule ExecutionPlane.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/execution_plane"
  @description """
  Execution Plane provides shared lower-runtime contracts, route planning,
  placement descriptors, process transport, HTTP execution, and JSON-RPC
  helpers for Elixir SDKs and runtime family kits.
  """

  def project do
    [
      app: :execution_plane,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: @description,
      aliases: aliases(),
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:inets, :logger, :ssl],
      mod: {ExecutionPlane.Application, []}
    ]
  end

  def cli do
    []
  end

  defp elixirc_paths(:test) do
    [
      "lib",
      "test/support",
      "core/execution_plane_contracts/lib",
      "core/execution_plane_kernel/lib",
      "protocols/execution_plane_http/lib",
      "protocols/execution_plane_jsonrpc/lib",
      "streaming/execution_plane_sse/lib",
      "streaming/execution_plane_websocket/lib",
      "placements/execution_plane_local/lib",
      "placements/execution_plane_ssh/lib",
      "placements/execution_plane_guest/lib",
      "runtimes/execution_plane_process/lib",
      "conformance/execution_plane_testkit/lib"
    ]
  end

  defp elixirc_paths(_env) do
    [
      "lib",
      "core/execution_plane_contracts/lib",
      "core/execution_plane_kernel/lib",
      "protocols/execution_plane_http/lib",
      "protocols/execution_plane_jsonrpc/lib",
      "streaming/execution_plane_sse/lib",
      "streaming/execution_plane_websocket/lib",
      "placements/execution_plane_local/lib",
      "placements/execution_plane_ssh/lib",
      "placements/execution_plane_guest/lib",
      "runtimes/execution_plane_process/lib",
      "conformance/execution_plane_testkit/lib"
    ]
  end

  defp deps do
    [
      {:erlexec, "~> 2.3"},
      {:finch, "~> 0.21"},
      {:jason, "~> 1.4"},
      {:mint_web_socket, "~> 1.0"},
      {:server_sent_events, "~> 0.2"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "workspace_overview",
      extras: [
        {"README.md", filename: "workspace_overview"},
        {"guides/index.md", filename: "guides_index"},
        {"core/execution_plane_contracts/README.md", filename: "execution_plane_contracts"},
        {"core/execution_plane_kernel/README.md", filename: "execution_plane_kernel"},
        {"protocols/execution_plane_http/README.md", filename: "execution_plane_http"},
        {"protocols/execution_plane_jsonrpc/README.md", filename: "execution_plane_jsonrpc"},
        {"streaming/execution_plane_sse/README.md", filename: "execution_plane_sse"},
        {"streaming/execution_plane_websocket/README.md", filename: "execution_plane_websocket"},
        {"placements/execution_plane_local/README.md", filename: "execution_plane_local"},
        {"placements/execution_plane_ssh/README.md", filename: "execution_plane_ssh"},
        {"placements/execution_plane_guest/README.md", filename: "execution_plane_guest"},
        {"runtimes/execution_plane_process/README.md", filename: "execution_plane_process"},
        {"conformance/execution_plane_testkit/README.md", filename: "execution_plane_testkit"}
      ],
      groups_for_extras: [
        Overview: ["README.md", "guides/index.md"],
        "Package Homes": [
          "core/execution_plane_contracts/README.md",
          "core/execution_plane_kernel/README.md",
          "protocols/execution_plane_http/README.md",
          "protocols/execution_plane_jsonrpc/README.md",
          "streaming/execution_plane_sse/README.md",
          "streaming/execution_plane_websocket/README.md",
          "placements/execution_plane_local/README.md",
          "placements/execution_plane_ssh/README.md",
          "placements/execution_plane_guest/README.md",
          "runtimes/execution_plane_process/README.md",
          "conformance/execution_plane_testkit/README.md"
        ]
      ],
      assets: %{"assets" => "assets"},
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
      exclude_patterns: [
        "**/_build/**",
        "**/deps/**",
        "**/doc/**",
        "**/*.beam",
        "**/*.plt",
        "**/*.plt.hash"
      ],
      files: ~w(
          .formatter.exs
          LICENSE
          README.md
          assets
          conformance/execution_plane_testkit
          core
          guides/index.md
          lib
          mix.exs
          placements
          protocols
          runtimes/execution_plane_process
          streaming
        )
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
