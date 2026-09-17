defmodule ExecutionPlane.HTTP.UnaryCancellationTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.HTTP

  test "cancelable unary preserves the normal kernel result on completion" do
    {server, endpoint} = start_http_server("ok")

    assert {:ok, session} =
             HTTP.start_unary(
               %{
                 url: endpoint <> "/probe",
                 method: "GET",
                 timeout_ms: 5_000
               },
               lineage: lineage("complete")
             )

    assert_receive {:http_server_request, ^server}, 1_000
    assert {:ok, result} = HTTP.await_unary(session, 1_000)
    assert result.outcome.status == "succeeded"
    assert Enum.map(result.events, & &1.event_type) == ["dispatch.started", "dispatch.completed"]
    assert result.outcome.raw_payload.status_code == 200
    assert result.outcome.raw_payload.body == "ok"
    assert :ok = HTTP.cancel_unary(session, :after_completion)

    stop_http_server(server)
  end

  test "cancelling an active unary request closes the real socket and yields cancellation" do
    {server, endpoint} = start_http_server(:hold)

    assert {:ok, session} =
             HTTP.start_unary(
               %{
                 url: endpoint <> "/probe",
                 method: "GET",
                 timeout_ms: 10_000
               },
               lineage: lineage("cancel")
             )

    assert_receive {:http_server_request, ^server}, 1_000

    cancel_task = Task.async(fn -> HTTP.cancel_unary(session, :test_cancel) end)
    assert :ok = Task.await(cancel_task, 1_000)
    assert :ok = HTTP.cancel_unary(session, :test_cancel_again)

    assert_receive {:http_server_socket_closed, ^server, {:error, :closed}}, 1_000
    assert_receive {:http_server_late_send_result, ^server, {:error, _reason}}, 1_000

    assert {:error, result} = HTTP.await_unary(session, 1_000)
    refute Process.alive?(session.worker)
    refute_received {:execution_plane_http_unary_finished, _, _, _}
    assert result.outcome.status == "failed"
    assert Enum.map(result.events, & &1.event_type) == ["dispatch.started", "dispatch.failed"]
    assert result.outcome.failure.failure_class == :cancellation
    assert result.outcome.failure.retryable? == false
    assert result.outcome.raw_payload.error == "cancelled"
    assert result.outcome.failure.details == %{}

    stop_http_server(server)
  end

  test "owner death cancels the physical request and does not orphan the worker" do
    {server, endpoint} = start_http_server(:hold)
    test_process = self()

    owner =
      spawn(fn ->
        result =
          HTTP.start_unary(
            %{
              url: endpoint <> "/probe",
              method: "GET",
              timeout_ms: 10_000
            },
            lineage: lineage("owner-down")
          )

        send(test_process, {:owned_unary_session, self(), result})

        receive do
          :finish -> :ok
        end
      end)

    assert_receive {:owned_unary_session, ^owner, {:ok, session}}, 1_000
    assert_receive {:http_server_request, ^server}, 1_000

    worker_monitor = Process.monitor(session.worker)
    Process.exit(owner, :kill)

    assert_receive {:http_server_socket_closed, ^server, {:error, :closed}}, 1_000
    assert_receive {:http_server_late_send_result, ^server, {:error, _reason}}, 1_000
    assert_receive {:DOWN, ^worker_monitor, :process, _worker, :normal}, 1_000

    stop_http_server(server)
  end

  test "a wait timeout cancels the socket and drains terminal messages and monitors" do
    {server, endpoint} = start_http_server(:hold)

    assert {:ok, session} =
             HTTP.start_unary(%{url: endpoint, method: "GET", timeout_ms: 10_000},
               lineage: lineage("wait-timeout")
             )

    assert_receive {:http_server_request, ^server}, 1_000
    assert {:error, :timeout} = HTTP.await_unary(session, 0)
    refute Process.alive?(session.worker)
    assert_receive {:http_server_socket_closed, ^server, {:error, :closed}}, 1_000
    refute_received {:execution_plane_http_unary_finished, _, _, _}
    refute_received {:DOWN, _, :process, _, _}
    stop_http_server(server)
  end

  test "a bad method fails before creating an active unary session" do
    assert {:error, result} =
             HTTP.start_unary(
               %{
                 url: "http://127.0.0.1:9/blocked",
                 method: "BREW",
                 timeout_ms: 100
               },
               lineage: lineage("bad-method")
             )

    assert result.outcome.status == "failed"
    assert result.outcome.failure.failure_class == :transport_failed
    assert result.outcome.failure.reason == "invalid http method"
  end

  defp lineage(suffix), do: %{idempotency_key: "idem-#{suffix}"}

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
            closed = :gen_tcp.recv(socket, 0, 5_000)
            send(owner, {:http_server_socket_closed, self(), closed})

            late_send =
              :gen_tcp.send(
                socket,
                "HTTP/1.1 200 OK\r\ncontent-length: 4\r\nconnection: close\r\n\r\nlate"
              )

            send(owner, {:http_server_late_send_result, self(), late_send})

          body ->
            payload =
              "HTTP/1.1 200 OK\r\ncontent-length: #{byte_size(body)}\r\n" <>
                "connection: close\r\n\r\n#{body}"

            :ok = :gen_tcp.send(socket, payload)
            send(owner, {:http_server_response_sent, self()})
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
