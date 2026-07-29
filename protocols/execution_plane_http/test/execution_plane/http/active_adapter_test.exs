defmodule ExecutionPlane.HTTP.ActiveAdapterTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Admission.Request
  alias ExecutionPlane.ExecutionRequest
  alias ExecutionPlane.Family.HTTPRequest
  alias ExecutionPlane.HTTP
  alias ExecutionPlane.HTTP.RuntimeClientGateway

  test "incremental HTTP delivers only demanded chunks before the terminal result" do
    {server, endpoint} = start_http_server("abcdef")
    request = execution_request(endpoint, "incremental")

    assert {:ok, session} =
             HTTP.active_start(request, self(),
               endpoints: %{"endpoint://test" => endpoint},
               header_policies: %{"headers://test" => %{}},
               http_chunk_bytes: 3
             )

    refute_receive {:execution_plane_http_active, {:output, _payload}}, 50

    assert :ok =
             HTTP.active_send_input(
               session,
               %{"control" => "demand", "count" => 1},
               []
             )

    assert_receive {:execution_plane_http_active,
                    {:output, %{"family" => "http", "stream" => "body", "data" => "abc"}}},
                   1_000

    refute_receive {:execution_plane_http_active, {:output, _payload}}, 50

    assert :ok =
             HTTP.active_send_input(
               session,
               %{"control" => "demand", "count" => 1},
               []
             )

    assert_receive {:execution_plane_http_active,
                    {:output, %{"family" => "http", "stream" => "body", "data" => "def"}}},
                   1_000

    assert_receive {:execution_plane_http_active,
                    {:terminal, "completed", %{status: "succeeded"} = result}}

    assert result.output["status_code"] == 200
    stop_http_server(server)
  end

  test "unary demand returns one semantic result and cancellation reaches httpc lifecycle" do
    {server, endpoint} = start_http_server("ok")
    request = execution_request(endpoint, "unary")

    assert {:ok, session} =
             HTTP.active_start(request, self(),
               endpoints: %{"endpoint://test" => endpoint},
               header_policies: %{"headers://test" => %{}}
             )

    assert :ok =
             HTTP.active_send_input(
               session,
               %{"control" => "demand", "count" => 1},
               []
             )

    assert_receive {:execution_plane_http_active,
                    {:output, %{"execution_result" => %{status: "succeeded"}}}},
                   1_000

    assert_receive {:execution_plane_http_active,
                    {:terminal, "completed", %{status: "succeeded"}}}

    stop_http_server(server)

    {slow_server, slow_endpoint} = start_http_server(:hold)
    slow_request = execution_request(slow_endpoint, "unary")

    assert {:ok, slow_session} =
             HTTP.active_start(slow_request, self(),
               endpoints: %{"endpoint://test" => slow_endpoint},
               header_policies: %{"headers://test" => %{}}
             )

    assert_receive {:http_server_request, ^slow_server}, 1_000
    monitor = Process.monitor(slow_session)
    assert :ok = HTTP.active_cancel(slow_session, "operator_cancel", [])
    assert_receive {:DOWN, ^monitor, :process, ^slow_session, :normal}, 1_000
    stop_http_server(slow_server)
  end

  test "untrusted endpoint refs fail closed without an HTTP request" do
    request = execution_request("http://127.0.0.1:1", "unary")

    assert {:error, {:unknown_http_materialization, :endpoints, "endpoint://test"}} =
             HTTP.active_start(request, self(),
               endpoints: %{},
               header_policies: %{"headers://test" => %{}}
             )
  end

  defp execution_request(_endpoint, response_mode) do
    family_request =
      HTTPRequest.new(%{
        request_ref: "request://test",
        endpoint_ref: "endpoint://test",
        method: "GET",
        path: "/probe",
        header_policy_ref: "headers://test",
        response_mode: response_mode,
        idempotency_key: "test-http-request",
        deadline_at: DateTime.add(DateTime.utc_now(), 60, :second)
      })
      |> elem(1)

    admission =
      Request.new!(
        lane_id: "http",
        operation: if(response_mode == "unary", do: "http.unary", else: "http.stream"),
        payload: %{
          "family" => "http",
          "family_contract" => "execution-plane.runtime-families.v1",
          "request" => RuntimeClientGateway.encode_request(family_request)
        },
        provenance: ExecutionPlane.Provenance.direct_lower_lane_owner("active-http-test")
      )

    ExecutionRequest.new!(
      execution_ref: ExecutionPlane.ExecutionRef.new!().ref,
      admission_request: admission,
      lane_id: "http",
      operation: admission.operation,
      payload: admission.payload,
      provenance: admission.provenance
    )
  end

  defp start_http_server(response) do
    {:ok, listen} =
      :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true])

    {:ok, port} = :inet.port(listen)
    owner = self()

    pid =
      spawn_link(fn ->
        {:ok, socket} = :gen_tcp.accept(listen)
        {:ok, _request} = :gen_tcp.recv(socket, 0, 2_000)
        send(owner, {:http_server_request, self()})

        case response do
          :hold ->
            receive do
              :stop -> :ok
            end

          body ->
            payload =
              "HTTP/1.1 200 OK\r\ncontent-length: #{byte_size(body)}\r\n" <>
                "connection: close\r\n\r\n#{body}"

            :ok = :gen_tcp.send(socket, payload)
        end

        :gen_tcp.close(socket)
        :gen_tcp.close(listen)
      end)

    {pid, "http://127.0.0.1:#{port}"}
  end

  defp stop_http_server(server) do
    monitor = Process.monitor(server)
    send(server, :stop)

    receive do
      {:DOWN, ^monitor, :process, ^server, _reason} -> :ok
    after
      1_000 ->
        Process.exit(server, :kill)
        :ok
    end
  end
end
