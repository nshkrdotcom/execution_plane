defmodule ExecutionPlane.HTTPTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.HTTP
  alias ExecutionPlane.Kernel.ExecutionResult
  alias ExecutionPlane.TestSupport.SimpleHTTPServer

  test "unary/2 executes unary HTTP on the frozen minimal lane surface" do
    server =
      SimpleHTTPServer.start(self(), fn request ->
        assert request.method == "POST"
        assert request.path == "/echo"
        assert request.body == ~s({"ping":"pong"})
        {201, [{"content-type", "application/json"}], ~s({"ok":true})}
      end)

    on_exit(fn -> Process.exit(server.pid, :kill) end)

    assert {:ok, %ExecutionResult{} = result} =
             HTTP.unary(
               %{
                 url: server.url <> "/echo",
                 method: :post,
                 headers: %{"content-type" => "application/json"},
                 body: ~s({"ping":"pong"}),
                 timeout_ms: 750
               },
               lineage: %{request_id: "request-http-1", idempotency_key: "idem-http-1"}
             )

    assert result.outcome.status == "succeeded"
    assert result.outcome.raw_payload.status_code == 201
    assert result.outcome.raw_payload.body == ~s({"ok":true})
    assert result.outcome.lineage.request_id == "request-http-1"
    assert result.outcome.lineage.idempotency_key == "idem-http-1"
    assert result.plan.intent.body == ~s({"ping":"pong"})
    assert result.plan.intent.envelope.requested_capabilities == ["http.unary"]

    assert_receive {:simple_http_request, %{headers: headers}}, 1_000
    assert headers["content-type"] == "application/json"
  end
end
