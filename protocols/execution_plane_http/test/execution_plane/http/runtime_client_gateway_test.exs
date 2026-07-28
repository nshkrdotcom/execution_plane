defmodule ExecutionPlane.HTTP.RuntimeClientGatewayTest.Client do
  @behaviour ExecutionPlane.Runtime.Client

  alias ExecutionPlane.ActiveExecution
  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.Runtime.{Event, Status}

  @impl true
  def start(request, opts) do
    notify({:start, request, opts})

    {:ok,
     ActiveExecution.new!(
       execution_ref: "execution://http/runtime-client-test",
       session_ref: "session://http/runtime-client-test",
       admission_decision_ref: "admission://http/runtime-client-test",
       node_id: "node://effect/runtime-client-test",
       lane_id: Keyword.get(opts, :returned_lane, request.lane_id),
       state: "running",
       started_at: DateTime.utc_now(),
       fence: 3
     )}
  end

  @impl true
  def subscribe(ref, subscriber, opts) do
    notify({:subscribe, ref, subscriber, opts})

    if Keyword.get(opts, :subscribe_error, false) do
      {:error, :subscription_failed}
    else
      maybe_send_unary_result(ref, subscriber, opts)
      :ok
    end
  end

  @impl true
  def send_input(ref, input, opts) do
    notify({:send_input, ref, input, opts})
    :ok
  end

  @impl true
  def end_input(_ref, _opts), do: :ok

  @impl true
  def status(ref, opts) do
    notify({:status, ref, opts})

    {:ok,
     Status.new!(
       execution_ref: ref,
       state: "running",
       sequence: 2,
       input_open: true,
       output_open: true
     )}
  end

  @impl true
  def cancel(ref, opts) do
    notify({:cancel, ref, opts})
    :ok
  end

  defp maybe_send_unary_result(ref, subscriber, opts) do
    unless Keyword.get(opts, :suppress_result, false) do
      result =
        ExecutionResult.new!(
          execution_ref: ref,
          status: "succeeded",
          output: %{
            "status_code" => 200,
            "headers" => %{"content-type" => "application/json"},
            "body" => ~s({"ok":true})
          }
        )

      send(
        subscriber,
        Event.new!(%{
          execution_ref: ref,
          sequence: 1,
          kind: "output",
          emitted_at: DateTime.utc_now(),
          payload: %{"chunk" => ~s({"ok")}
        })
      )

      send(
        subscriber,
        Event.new!(%{
          execution_ref: ref,
          sequence: 2,
          kind: "output",
          emitted_at: DateTime.utc_now(),
          payload: %{"execution_result" => result}
        })
      )

      send(
        subscriber,
        Event.new!(%{
          execution_ref: ref,
          sequence: 3,
          kind: "receipt",
          emitted_at: DateTime.utc_now(),
          payload: %{
            "execution_result" => result,
            "receipt_ref" => "receipt://http/runtime-client-test"
          }
        })
      )
    end
  end

  defp notify(message) do
    if owner = Process.whereis(ExecutionPlane.HTTP.RuntimeClientGatewayTest.Owner) do
      send(owner, message)
    end
  end
end

defmodule ExecutionPlane.HTTP.RuntimeClientGatewayTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Family.HTTPRequest
  alias ExecutionPlane.HTTP.RuntimeClientGateway
  alias ExecutionPlane.HTTP.RuntimeClientGatewayTest.Client

  @owner __MODULE__.Owner

  setup do
    Process.register(self(), @owner)

    on_exit(fn ->
      if Process.whereis(@owner), do: Process.unregister(@owner)
    end)

    :ok
  end

  test "runs unary HTTP through admission, explicit demand, and a runtime result event" do
    family_request = request("unary")

    assert {:ok, result} =
             RuntimeClientGateway.unary(family_request,
               runtime_client: Client,
               runtime_client_opts: [server: {:effect_server, :effect_node}],
               admission: %{
                 request_id: "admission-request://http/1",
                 authority_ref: %{ref: "grant://citadel/http/1"}
               }
             )

    assert result.status == "succeeded"
    assert result.output["status_code"] == 200

    assert_receive {:start, admission, [server: {:effect_server, :effect_node}]}
    assert admission.lane_id == "http"
    assert admission.operation == "http.unary"

    assert {:ok, ^family_request} =
             RuntimeClientGateway.decode_request(admission.payload["request"])

    assert {:ok, _encoded} = ExecutionPlane.Codec.encode(admission)

    assert_receive {:send_input, %{ref: "execution://http/runtime-client-test"},
                    %{"control" => "demand", "count" => 1},
                    [server: {:effect_server, :effect_node}]}
  end

  test "starts incremental HTTP, preserves subscriber identity, and delegates demand" do
    opts = [runtime_client: Client, runtime_client_opts: [server: :effect_server]]

    assert {:ok, active} = RuntimeClientGateway.stream(request("incremental"), self(), opts)
    assert active.lane_id == "http"
    assert :ok = RuntimeClientGateway.demand(active.execution_ref, 4, opts)

    assert_receive {:start, admission, [server: :effect_server]}
    assert admission.operation == "http.stream"

    assert_receive {:subscribe, %{ref: "execution://http/runtime-client-test"}, subscriber,
                    [server: :effect_server]}

    assert subscriber == self()

    assert_receive {:send_input, %{ref: "execution://http/runtime-client-test"},
                    %{"control" => "demand", "count" => 4}, [server: :effect_server]}
  end

  test "subscription failure performs real cancellation" do
    assert {:error, :subscription_failed} =
             RuntimeClientGateway.stream(request("incremental"), self(),
               runtime_client: Client,
               runtime_client_opts: [subscribe_error: true]
             )

    assert_receive {:cancel, %{ref: "execution://http/runtime-client-test"}, opts}
    assert opts[:reason] == "subscription_failed"
  end

  test "unary timeout performs real cancellation and returns a bounded error" do
    assert {:error, :runtime_result_timeout} =
             RuntimeClientGateway.unary(request("unary"),
               runtime_client: Client,
               runtime_client_opts: [suppress_result: true],
               receive_timeout: 5
             )

    assert_receive {:cancel, %{ref: "execution://http/runtime-client-test"}, opts}
    assert opts[:reason] == "unary_result_timeout"
  end

  test "rejects mode mismatches and invalid demand before dispatch" do
    assert {:error, :http_response_mode_mismatch} =
             RuntimeClientGateway.unary(request("incremental"), runtime_client: Client)

    assert {:error, :http_response_mode_mismatch} =
             RuntimeClientGateway.stream(request("unary"), self(), runtime_client: Client)

    assert {:error, :invalid_http_demand} =
             RuntimeClientGateway.demand(
               "execution://http/runtime-client-test",
               1_025,
               runtime_client: Client
             )

    assert {:error, {:raw_credential_key_forbidden, "api_key"}} =
             RuntimeClientGateway.unary(request("unary"),
               runtime_client: Client,
               admission: %{metadata: %{"api_key" => "sentinel-secret"}}
             )

    refute_receive {:start, _request, _opts}
  end

  defp request(response_mode) do
    HTTPRequest.new(%{
      request_ref: "request://gemini/1",
      endpoint_ref: "endpoint://google/gemini",
      method: "POST",
      path: "/v1/models/gemini:generateContent",
      header_policy_ref: "header-policy://jido/gemini/1",
      response_mode: response_mode,
      idempotency_key: "gemini:1",
      deadline_at: DateTime.add(DateTime.utc_now(), 60, :second),
      body_artifact_ref: "artifact://outer-brain/prompt/1"
    })
    |> elem(1)
  end
end
