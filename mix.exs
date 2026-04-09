defmodule ExecutionPlane.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/execution_plane"
  @description """
  Execution Plane is the workspace-style lower runtime substrate for the Brain /
  Spine / Execution Plane architecture, freezing the shared contract packet,
  package topology, and lower-boundary ownership rules before broader runtime
  extraction waves begin.
  """

  def project do
    [
      app: :execution_plane,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
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
      extra_applications: [:inets, :logger, :ssl],
      mod: {ExecutionPlane.Application, []}
    ]
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
      {:erlexec, "~> 2.2"},
      {:finch, "~> 0.19"},
      {:jason, "~> 1.4"},
      {:mint_web_socket, "~> 1.0"},
      {:server_sent_events, "~> 0.2"},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "workspace_overview",
      extras: [
        {"README.md", filename: "workspace_overview"},
        {"guides/index.md", filename: "guides_index"},
        "technical/01_north_star_architecture.md",
        "technical/02_repo_topology_and_package_map.md",
        "technical/03_shared_contracts_and_lineage.md",
        "technical/04_http_graphql_and_realtime_family_design.md",
        "technical/05_process_and_agent_session_family_design.md",
        "technical/07_brain_spine_and_harness_alignment.md",
        "technical/10_subset_complete_big_bang_execution_model.md",
        "technical/11_surface_exposure_and_contract_carriage_matrix.md",
        "technical/12_repo_quality_gate_command_matrix.md",
        "JIDO_BRAIN_CONTRACT_CONTEXT/README.md",
        "JIDO_BRAIN_CONTRACT_CONTEXT/01_authority_decision_v1_packet_baseline.md",
        "prompts/00_master_orchestrator_prompt.md",
        "prompts/01_contract_packet_and_execution_plane_foundation_checklist.md",
        "prompts/01_contract_packet_and_execution_plane_foundation_implementation_prompt.md",
        "prompts/02_execution_plane_kernel_and_minimal_topology_checklist.md",
        "prompts/02_execution_plane_kernel_and_minimal_topology_implementation_prompt.md",
        "prompts/03_minimal_viable_http_and_process_lanes_prove_out_checklist.md",
        "prompts/03_minimal_viable_http_and_process_lanes_prove_out_implementation_prompt.md",
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
        {"sandboxes/execution_plane_container/README.md", filename: "execution_plane_container"},
        {"sandboxes/execution_plane_microvm/README.md", filename: "execution_plane_microvm"},
        {"conformance/execution_plane_testkit/README.md", filename: "execution_plane_testkit"},
        "adrs/ADR-001-brain-spine-execution-plane-is-the-top-level-system-split.md",
        "adrs/ADR-002-create-execution_plane-as-a-new-workspace-repo.md",
        "adrs/ADR-003-share-lineage-and-route-contracts-not-one-mega-struct.md",
        "adrs/ADR-004-pristine-remains-the-http-family-kit.md",
        "adrs/ADR-006-reqllm_next-adopts-the-shared-http-and-realtime-family.md",
        "adrs/ADR-007-cli_subprocess_core-remains-the-cli-family-kit-above-execution-plane.md",
        "adrs/ADR-008-provider-sdks-keep-provider-semantics-and-drop-runtime-ownership.md",
        "adrs/ADR-009-asm-remains-the-agent-session-kernel-and-jido_harness-remains-a-facade.md",
        "adrs/ADR-011-jido_integration-is-the-spine-and-jido_os-is-the-brain.md",
        "adrs/ADR-012-no-staged-compatibility-shims-or-intermediate-public-apis.md",
        "adrs/ADR-014-execute-the-program-as-subset-complete-capability-waves.md",
        "adrs/ADR-015-public-surfaces-expose-mapped-family-and-facade-irs-not-raw-execution-plane-packages.md",
        "adrs/ADR-016-upstream-fixes-are-allowed-within-the-active-wave.md",
        "brain_spine_execution_plane_architecture_review.md"
      ],
      groups_for_extras: [
        Overview: ["README.md", "guides/index.md"],
        Packet: [
          "technical/01_north_star_architecture.md",
          "technical/02_repo_topology_and_package_map.md",
          "technical/03_shared_contracts_and_lineage.md",
          "technical/04_http_graphql_and_realtime_family_design.md",
          "technical/05_process_and_agent_session_family_design.md",
          "technical/07_brain_spine_and_harness_alignment.md",
          "technical/10_subset_complete_big_bang_execution_model.md",
          "technical/11_surface_exposure_and_contract_carriage_matrix.md",
          "technical/12_repo_quality_gate_command_matrix.md"
        ],
        "Brain Contract Context": [
          "JIDO_BRAIN_CONTRACT_CONTEXT/README.md",
          "JIDO_BRAIN_CONTRACT_CONTEXT/01_authority_decision_v1_packet_baseline.md"
        ],
        Prompts: [
          "prompts/00_master_orchestrator_prompt.md",
          "prompts/01_contract_packet_and_execution_plane_foundation_checklist.md",
          "prompts/01_contract_packet_and_execution_plane_foundation_implementation_prompt.md",
          "prompts/02_execution_plane_kernel_and_minimal_topology_checklist.md",
          "prompts/02_execution_plane_kernel_and_minimal_topology_implementation_prompt.md",
          "prompts/03_minimal_viable_http_and_process_lanes_prove_out_checklist.md",
          "prompts/03_minimal_viable_http_and_process_lanes_prove_out_implementation_prompt.md"
        ],
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
          "sandboxes/execution_plane_container/README.md",
          "sandboxes/execution_plane_microvm/README.md",
          "conformance/execution_plane_testkit/README.md"
        ],
        ADRs: [
          "adrs/ADR-001-brain-spine-execution-plane-is-the-top-level-system-split.md",
          "adrs/ADR-002-create-execution_plane-as-a-new-workspace-repo.md",
          "adrs/ADR-003-share-lineage-and-route-contracts-not-one-mega-struct.md",
          "adrs/ADR-004-pristine-remains-the-http-family-kit.md",
          "adrs/ADR-006-reqllm_next-adopts-the-shared-http-and-realtime-family.md",
          "adrs/ADR-007-cli_subprocess_core-remains-the-cli-family-kit-above-execution-plane.md",
          "adrs/ADR-008-provider-sdks-keep-provider-semantics-and-drop-runtime-ownership.md",
          "adrs/ADR-009-asm-remains-the-agent-session-kernel-and-jido_harness-remains-a-facade.md",
          "adrs/ADR-011-jido_integration-is-the-spine-and-jido_os-is-the-brain.md",
          "adrs/ADR-012-no-staged-compatibility-shims-or-intermediate-public-apis.md",
          "adrs/ADR-014-execute-the-program-as-subset-complete-capability-waves.md",
          "adrs/ADR-015-public-surfaces-expose-mapped-family-and-facade-irs-not-raw-execution-plane-packages.md",
          "adrs/ADR-016-upstream-fixes-are-allowed-within-the-active-wave.md"
        ],
        Review: ["brain_spine_execution_plane_architecture_review.md"]
      ],
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
      files: ~w(
          .formatter.exs
          LICENSE
          README.md
          JIDO_BRAIN_CONTRACT_CONTEXT
          adrs
          assets
          brain_spine_execution_plane_architecture_review.md
          conformance
          core
          guides
          lib
          mix.exs
          placements
          prompts
          protocols
          runtimes
          sandboxes
          streaming
          technical
          test
        )
    ]
  end
end
