defmodule ExecutionPlane.NodeRuntimeFamiliesIntegrationTest do
  use ExUnit.Case, async: false

  alias Elixir.Process, as: BEAMProcess
  alias ExecutionPlane.Authority.Ref
  alias ExecutionPlane.Family.{HTTPRequest, ProcessRequest}
  alias ExecutionPlane.HTTP
  alias ExecutionPlane.HTTP.RuntimeClientGateway, as: HTTPGateway

  alias ExecutionPlane.Node.{
    DistributedClient,
    ExecutionRegistry,
    ExecutionSupervisor,
    LocalHTTPWeakVerifier,
    LocalWeakVerifier,
    Server
  }

  alias ExecutionPlane.Node.TargetClient.Adapter, as: TargetClientAdapter
  alias ExecutionPlane.NodeTest.AuthorityVerifier
  alias ExecutionPlane.Placement.Surface
  alias ExecutionPlane.Process
  alias ExecutionPlane.Process.RuntimeClientGateway, as: ProcessGateway
  alias ExecutionPlane.Runtime.Event
  alias ExecutionPlane.Sandbox.{AcceptableAttestation, Profile}

  test "local active node owns interactive process and demanded HTTP lifecycles" do
    %{server: server} = start_isolated_node()

    :ok =
      Server.register_lane(server, Process,
        active_options: [
          working_directories: %{"workspace://tmp" => "/tmp"},
          environment_materializations: %{"environment://empty" => %{}}
        ]
      )

    assert_process_round_trip(server)

    {http_server, endpoint} = start_http_server("remote-body")

    :ok =
      Server.register_lane(server, HTTP,
        active_options: [
          endpoints: %{"endpoint://test" => endpoint},
          header_policies: %{"headers://test" => %{}}
        ]
      )

    assert_http_round_trip(server)
    stop_http_server(http_server)
  end

  test "peer-backed Runtime Client observes process and HTTP effects on a second BEAM node" do
    ensure_distribution()
    peer_name = :"execution_plane_effect_#{System.unique_integer([:positive])}"
    {:ok, peer, peer_node} = :peer.start_link(%{name: peer_name, wait_boot: 10_000})

    try do
      :ok = :rpc.call(peer_node, :code, :add_paths, [:code.get_path()])

      assert {:ok, _apps} =
               :rpc.call(peer_node, Application, :ensure_all_started, [:execution_plane_process])

      assert {:ok, _apps} =
               :rpc.call(peer_node, Application, :ensure_all_started, [:execution_plane_http])

      assert {:ok, _apps} =
               :rpc.call(peer_node, Application, :ensure_all_started, [:execution_plane_node])

      {http_server, endpoint} = start_http_server("peer-http", 2)

      assert :ok =
               :rpc.call(peer_node, ExecutionPlane.Node, :register_lane, [
                 Process,
                 [
                   active_options: [
                     working_directories: %{"workspace://tmp" => "/tmp"},
                     environment_materializations: %{"environment://empty" => %{}}
                   ]
                 ]
               ])

      assert :ok =
               :rpc.call(peer_node, ExecutionPlane.Node, :register_lane, [
                 HTTP,
                 [
                   active_options: [
                     endpoints: %{"endpoint://test" => endpoint},
                     header_policies: %{"headers://test" => %{}}
                   ]
                 ]
               ])

      connect_governed_peer_targets(peer_node)

      server = {Server, peer_node}
      assert_peer_process_round_trip(server, peer_node)
      assert_http_round_trip(server, governed_admission("http", "local-http-weak"))
      assert_peer_http_stream(server)
      stop_http_server(http_server)

      {slow_http_server, slow_endpoint} = start_http_server(:hold)

      assert :ok =
               :rpc.call(peer_node, ExecutionPlane.Node, :register_lane, [
                 HTTP,
                 [
                   active_options: [
                     endpoints: %{"endpoint://test" => slow_endpoint},
                     header_policies: %{"headers://test" => %{}}
                   ]
                 ]
               ])

      assert_peer_http_cancel(server, slow_http_server)
      stop_http_server(slow_http_server)
    after
      :peer.stop(peer)
    end
  end

  defp start_isolated_node do
    suffix = System.unique_integer([:positive])
    registry = :"families_registry_#{suffix}"
    supervisor = :"families_supervisor_#{suffix}"
    server = :"families_server_#{suffix}"

    start_supervised!({ExecutionRegistry, name: registry})
    start_supervised!({ExecutionSupervisor, name: supervisor})

    start_supervised!(
      {Server,
       name: server,
       node_id: "families-node",
       execution_registry: registry,
       execution_supervisor: supervisor}
    )

    %{server: server}
  end

  defp assert_process_round_trip(server) do
    request =
      ProcessRequest.new(%{
        command_ref: "command://test/cat",
        executable: "/bin/cat",
        arguments: [],
        working_directory_ref: "workspace://tmp",
        environment_materialization_ref: "environment://empty",
        stdin_mode: "pipe",
        deadline_at: DateTime.add(DateTime.utc_now(), 30, :second)
      })
      |> elem(1)

    opts = process_gateway_opts(server)
    assert {:ok, active} = ProcessGateway.start(request, opts)
    lifecycle_opts = put_fence(opts, active.fence)
    assert :ok = ProcessGateway.attach(active.execution_ref, self(), lifecycle_opts)
    assert :ok = ProcessGateway.send_input(active.execution_ref, "composed\n", lifecycle_opts)
    assert :ok = ProcessGateway.end_input(active.execution_ref, lifecycle_opts)

    events = collect_until_receipt(active.execution_ref.ref)

    assert Enum.any?(events, fn
             %Event{kind: "output", payload: %{"data" => "composed"}} -> true
             _event -> false
           end)

    assert %Event{payload: %{"terminal_state" => "completed"}} = List.last(events)
  end

  defp assert_peer_process_round_trip(server, peer_node) do
    request =
      ProcessRequest.new(%{
        command_ref: "command://test/peer-echo",
        executable: "/bin/echo",
        arguments: ["peer-effect"],
        working_directory_ref: "workspace://tmp",
        environment_materialization_ref: "environment://empty",
        stdin_mode: "none",
        deadline_at: DateTime.add(DateTime.utc_now(), 30, :second)
      })
      |> elem(1)

    opts = process_gateway_opts(server, governed_admission("process", "local-erlexec-weak"))
    assert {:ok, active} = ProcessGateway.start(request, opts)
    assert active.node_id != "families-node"

    assert :ok =
             ProcessGateway.attach(active.execution_ref, self(), put_fence(opts, active.fence))

    events = collect_until_receipt(active.execution_ref.ref)

    assert Enum.any?(events, fn
             %Event{kind: "output", payload: %{"data" => "peer-effect"}} -> true
             _event -> false
           end)

    assert Node.ping(peer_node) == :pong
  end

  defp assert_http_round_trip(server, admission \\ direct_admission("http")) do
    request =
      HTTPRequest.new(%{
        request_ref: "request://test/http",
        endpoint_ref: "endpoint://test",
        method: "GET",
        path: "/probe",
        header_policy_ref: "headers://test",
        response_mode: "unary",
        idempotency_key: "runtime-families-http",
        deadline_at: DateTime.add(DateTime.utc_now(), 30, :second)
      })
      |> elem(1)

    assert {:ok, result} =
             HTTPGateway.unary(request,
               runtime_client: DistributedClient,
               runtime_client_opts: [server: server],
               admission: admission
             )

    assert result.status == "succeeded"
    assert result.output["status_code"] == 200
  end

  defp assert_peer_http_stream(server) do
    request = http_request("incremental", "runtime-families-http-stream")

    opts = [
      runtime_client: DistributedClient,
      runtime_client_opts: [server: server],
      admission: governed_admission("http", "local-http-weak")
    ]

    assert {:ok, active} = HTTPGateway.stream(request, self(), opts)
    demand_opts = put_fence(opts, active.fence)
    assert :ok = HTTPGateway.demand(active.execution_ref, 1, demand_opts)
    events = collect_until_receipt(active.execution_ref.ref)

    assert Enum.any?(events, fn
             %Event{
               kind: "output",
               payload: %{"family" => "http", "stream" => "body", "data" => "peer-http"}
             } ->
               true

             _event ->
               false
           end)

    assert %Event{payload: %{"terminal_state" => "completed"}} = List.last(events)
  end

  defp assert_peer_http_cancel(server, http_server) do
    request = http_request("incremental", "runtime-families-http-cancel")

    opts = [
      runtime_client: DistributedClient,
      runtime_client_opts: [server: server],
      admission: governed_admission("http", "local-http-weak")
    ]

    assert {:ok, active} = HTTPGateway.stream(request, self(), opts)
    assert_receive {:http_server_request, ^http_server}, 1_000
    lifecycle_opts = put_fence(opts, active.fence)
    assert :ok = HTTPGateway.cancel(active.execution_ref, lifecycle_opts)

    assert %Event{payload: %{"terminal_state" => "cancelled"}} =
             active.execution_ref.ref
             |> collect_until_receipt()
             |> List.last()
  end

  defp http_request(response_mode, idempotency_key) do
    HTTPRequest.new(%{
      request_ref: "request://test/http/#{idempotency_key}",
      endpoint_ref: "endpoint://test",
      method: "GET",
      path: "/probe",
      header_policy_ref: "headers://test",
      response_mode: response_mode,
      idempotency_key: idempotency_key,
      deadline_at: DateTime.add(DateTime.utc_now(), 30, :second)
    })
    |> elem(1)
  end

  defp process_gateway_opts(server, admission \\ direct_admission("process")) do
    [
      runtime_client: DistributedClient,
      runtime_client_opts: [server: server],
      admission: admission
    ]
  end

  defp put_fence(opts, fence) do
    Keyword.update!(opts, :runtime_client_opts, &Keyword.put(&1, :fence, fence))
  end

  defp direct_admission(family) do
    %{
      request_id: "request://runtime-families/#{family}/#{System.unique_integer([:positive])}",
      provenance:
        ExecutionPlane.Provenance.direct_lower_lane_owner("runtime-families-integration")
    }
  end

  defp governed_admission(family, attestation_class) do
    %{
      request_id:
        "request://runtime-families/governed/#{family}/#{System.unique_integer([:positive])}",
      authority_ref: Ref.new!(ref: "allow"),
      sandbox_profile:
        Profile.new!(
          profile_ref: "sandbox://runtime-families/#{family}",
          bundle_hash: "sha256:runtime-families-#{family}"
        ),
      acceptable_attestation:
        AcceptableAttestation.new!(
          classes: [attestation_class],
          priority_order: [attestation_class]
        ),
      placement:
        Surface.new!(
          surface_kind: "runtime_node",
          family: family,
          metadata: %{"target_id" => "peer-#{family}-target"}
        )
    }
  end

  defp connect_governed_peer_targets(peer_node) do
    assert :ok =
             :rpc.call(peer_node, ExecutionPlane.Node, :register_target_verifier, [
               LocalWeakVerifier,
               []
             ])

    assert :ok =
             :rpc.call(peer_node, ExecutionPlane.Node, :register_target_verifier, [
               LocalHTTPWeakVerifier,
               []
             ])

    assert :ok =
             :rpc.call(peer_node, ExecutionPlane.Node, :register_authority_verifier, [
               AuthorityVerifier,
               []
             ])

    process_attestation =
      LocalWeakVerifier.mint_attestation(
        target_id: "peer-process-target",
        lane_id: "process"
      )

    assert {:ok, %{lane_id: "process", attested_capability_classes: ["local-erlexec-weak"]}} =
             :rpc.call(peer_node, ExecutionPlane.Node, :connect_target, [
               process_attestation,
               TargetClientAdapter,
               [target_id: "peer-process-target", lane_id: "process"]
             ])

    http_attestation =
      LocalHTTPWeakVerifier.mint_attestation(target_id: "peer-http-target")

    assert {:ok, %{lane_id: "http", attested_capability_classes: ["local-http-weak"]}} =
             :rpc.call(peer_node, ExecutionPlane.Node, :connect_target, [
               http_attestation,
               TargetClientAdapter,
               [target_id: "peer-http-target", lane_id: "http"]
             ])

    assert :ok =
             :rpc.call(peer_node, ExecutionPlane.Node, :complete_registration, [[]])
  end

  defp collect_until_receipt(ref, acc \\ []) do
    receive do
      {:execution_plane_runtime, ^ref, %Event{kind: "receipt"} = event} ->
        Enum.reverse([event | acc])

      {:execution_plane_runtime, ^ref, %Event{} = event} ->
        collect_until_receipt(ref, [event | acc])
    after
      3_000 -> flunk("timed out waiting for terminal receipt for #{ref}")
    end
  end

  defp ensure_distribution do
    unless Node.alive?() do
      name = :"execution_plane_controller_#{System.unique_integer([:positive])}"
      assert {:ok, _pid} = :net_kernel.start([name, :shortnames])
    end
  end

  defp start_http_server(body, request_count \\ 1) do
    {:ok, listen} =
      :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true])

    {:ok, port} = :inet.port(listen)

    owner = self()

    pid =
      spawn_link(fn ->
        serve_http_requests(listen, body, request_count, owner)
        :gen_tcp.close(listen)
      end)

    {pid, "http://127.0.0.1:#{port}"}
  end

  defp serve_http_requests(_listen, _body, 0, _owner), do: :ok

  defp serve_http_requests(listen, body, remaining, owner) do
    {:ok, socket} = :gen_tcp.accept(listen)
    {:ok, _request} = :gen_tcp.recv(socket, 0, 2_000)
    send(owner, {:http_server_request, self()})

    case body do
      :hold ->
        receive do
          :stop -> :ok
        end

      body ->
        response =
          "HTTP/1.1 200 OK\r\ncontent-length: #{byte_size(body)}\r\n" <>
            "connection: close\r\n\r\n#{body}"

        :ok = :gen_tcp.send(socket, response)
    end

    :gen_tcp.close(socket)
    serve_http_requests(listen, body, remaining - 1, owner)
  end

  defp stop_http_server(server) do
    monitor = BEAMProcess.monitor(server)
    send(server, :stop)

    receive do
      {:DOWN, ^monitor, :process, ^server, _reason} -> :ok
    after
      1_000 ->
        BEAMProcess.exit(server, :kill)
        :ok
    end
  end
end
