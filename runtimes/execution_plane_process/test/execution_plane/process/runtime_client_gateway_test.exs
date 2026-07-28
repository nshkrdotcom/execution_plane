defmodule ExecutionPlane.Process.RuntimeClientGatewayTest.Client do
  @behaviour ExecutionPlane.Runtime.Client

  alias ExecutionPlane.ActiveExecution
  alias ExecutionPlane.Runtime.Status

  @impl true
  def start(request, opts) do
    notify({:start, request, opts})

    {:ok,
     ActiveExecution.new!(
       execution_ref: "execution://process/runtime-client-test",
       session_ref: "session://process/runtime-client-test",
       admission_decision_ref: "admission://process/runtime-client-test",
       node_id: "node://effect/runtime-client-test",
       lane_id: Keyword.get(opts, :returned_lane, request.lane_id),
       state: "running",
       started_at: DateTime.utc_now(),
       fence: 7
     )}
  end

  @impl true
  def subscribe(ref, subscriber, opts) do
    notify({:subscribe, ref, subscriber, opts})
    :ok
  end

  @impl true
  def send_input(ref, input, opts) do
    notify({:send_input, ref, input, opts})
    :ok
  end

  @impl true
  def end_input(ref, opts) do
    notify({:end_input, ref, opts})
    :ok
  end

  @impl true
  def status(ref, opts) do
    notify({:status, ref, opts})

    {:ok,
     Status.new!(
       execution_ref: ref,
       state: "running",
       sequence: 3,
       input_open: true,
       output_open: true
     )}
  end

  @impl true
  def cancel(ref, opts) do
    notify({:cancel, ref, opts})
    :ok
  end

  defp notify(message) do
    if owner = Process.whereis(ExecutionPlane.Process.RuntimeClientGatewayTest.Owner) do
      send(owner, message)
    end
  end
end

defmodule ExecutionPlane.Process.RuntimeClientGatewayTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Family.ProcessRequest
  alias ExecutionPlane.Process.RuntimeClientGateway
  alias ExecutionPlane.Process.RuntimeClientGatewayTest.Client

  @owner __MODULE__.Owner

  setup do
    Process.register(self(), @owner)

    on_exit(fn ->
      if Process.whereis(@owner), do: Process.unregister(@owner)
    end)

    :ok
  end

  test "starts through the injected Runtime Client with a fixed process admission lane" do
    family_request = request()

    assert {:ok, active} =
             RuntimeClientGateway.start(family_request,
               runtime_client: Client,
               runtime_client_opts: [server: {:effect_server, :effect_node}],
               admission: %{
                 request_id: "admission-request://process/1",
                 authority_ref: %{ref: "grant://citadel/process/1"},
                 metadata: %{"consumer" => "cli_subprocess_core"}
               }
             )

    assert active.lane_id == "process"

    assert_receive {:start, admission, [server: {:effect_server, :effect_node}]}
    assert admission.lane_id == "process"
    assert admission.operation == "process.start"
    assert admission.payload["family"] == "process"

    assert {:ok, ^family_request} =
             RuntimeClientGateway.decode_request(admission.payload["request"])

    assert {:ok, _encoded} = ExecutionPlane.Codec.encode(admission)
    assert admission.metadata["family_contract"] == "execution-plane.runtime-families.v1"
    assert admission.metadata["consumer"] == "cli_subprocess_core"
  end

  test "delegates input, EOF, status, cancellation, and termination using opaque refs" do
    opts = [runtime_client: Client, runtime_client_opts: [server: :effect_server]]
    ref = "execution://process/runtime-client-test"

    assert :ok = RuntimeClientGateway.attach(ref, self(), opts)
    assert :ok = RuntimeClientGateway.send_input(ref, "hello\n", opts)
    assert :ok = RuntimeClientGateway.end_input(ref, opts)
    assert {:ok, status} = RuntimeClientGateway.status(ref, opts)
    assert status.state == "running"
    assert :ok = RuntimeClientGateway.cancel(ref, opts)
    assert :ok = RuntimeClientGateway.terminate(ref, opts)

    assert_receive {:subscribe, %{ref: ^ref}, subscriber, [server: :effect_server]}
    assert subscriber == self()
    assert_receive {:send_input, %{ref: ^ref}, "hello\n", [server: :effect_server]}
    assert_receive {:end_input, %{ref: ^ref}, [server: :effect_server]}
    assert_receive {:status, %{ref: ^ref}, [server: :effect_server]}
    assert_receive {:cancel, %{ref: ^ref}, [server: :effect_server]}

    assert_receive {:cancel, %{ref: ^ref}, [reason: "terminated", server: :effect_server]}
  end

  test "cancels a mismatched returned lane instead of accepting it" do
    assert {:error, :runtime_lane_mismatch} =
             RuntimeClientGateway.start(request(),
               runtime_client: Client,
               runtime_client_opts: [returned_lane: "http"]
             )

    assert_receive {:cancel, %{ref: "execution://process/runtime-client-test"}, opts}
    assert opts[:reason] == "runtime_lane_mismatch"
  end

  test "fails before dispatch for expired deadlines and invalid clients" do
    expired = %{request() | deadline_at: DateTime.add(DateTime.utc_now(), -1, :second)}

    assert {:error, :deadline_expired} =
             RuntimeClientGateway.start(expired, runtime_client: Client)

    assert {:error, :invalid_runtime_client} =
             RuntimeClientGateway.start(request(), runtime_client: String)

    assert {:error, {:raw_credential_key_forbidden, "api_key"}} =
             RuntimeClientGateway.start(request(),
               runtime_client: Client,
               admission: %{metadata: %{"api_key" => "sentinel-secret"}}
             )

    refute_receive {:start, _request, _opts}
  end

  defp request do
    ProcessRequest.new(%{
      command_ref: "command://cli-core/codex/1",
      executable: "codex",
      arguments: ["app-server"],
      working_directory_ref: "workspace://synapse/run-1",
      environment_materialization_ref: "materialization://jido/codex/1",
      stdin_mode: "pipe",
      deadline_at: DateTime.add(DateTime.utc_now(), 60, :second)
    })
    |> elem(1)
  end
end
