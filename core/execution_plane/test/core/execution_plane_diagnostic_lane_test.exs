defmodule ExecutionPlane.DiagnosticLaneTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.DiagnosticResult
  alias ExecutionPlane.ExecutionRequest
  alias ExecutionPlane.Lanes.DiagnosticLane

  test "diagnostic result normalizes bounded statuses and serializes" do
    result =
      DiagnosticResult.new!(
        operation: "diagnostic.echo",
        status: "ok",
        payload: %{"message" => "hello"},
        execution_time_ms: 0,
        target_class: "local-erlexec-weak",
        attestation: "weak_local"
      )

    assert result.status == :ok
    assert DiagnosticResult.dump(result)["status"] == "ok"
  end

  test "lane capabilities register a non-coding local diagnostic adapter" do
    capabilities = DiagnosticLane.capabilities()

    assert DiagnosticLane.lane_id() == :diagnostic
    assert capabilities.lane_id == "diagnostic"
    assert capabilities.protocols == ["diagnostic"]
    assert "local-erlexec-weak" in capabilities.surfaces
    assert capabilities.supports_execute == true
    assert capabilities.supports_stream == false
  end

  test "echo operation returns deterministic structured payload without shell interpretation" do
    message = "hello; rm -rf /"

    assert {:ok, result} =
             DiagnosticLane.execute(
               request("diagnostic.echo", %{"message" => message}),
               []
             )

    diagnostic = result.output["diagnostic_result"]

    assert result.status == "succeeded"
    assert diagnostic["operation"] == "diagnostic.echo"
    assert diagnostic["status"] == "ok"
    assert diagnostic["payload"]["message"] == message
    assert diagnostic["target_class"] == "local-erlexec-weak"
    assert diagnostic["attestation"] == "weak_local"
    assert is_integer(diagnostic["execution_time_ms"])
  end

  test "system info operation returns bounded runtime facts and no credentials" do
    assert {:ok, result} =
             DiagnosticLane.execute(request("diagnostic.system_info"), [])

    payload = result.output["diagnostic_result"]["payload"]

    assert is_binary(payload["otp_release"])
    assert is_binary(payload["elixir_version"])
    assert is_integer(payload["scheduler_count"])
    refute Map.has_key?(payload, "env")
    refute Map.has_key?(payload, "credentials")
  end

  test "workspace stat returns filesystem metadata without file content" do
    path = Path.join(System.tmp_dir!(), "execution-plane-diagnostic-lane-test.txt")
    File.write!(path, "secret-file-content")

    on_exit(fn -> File.rm(path) end)

    assert {:ok, result} =
             DiagnosticLane.execute(
               request("diagnostic.workspace_stat", %{"path" => path}),
               []
             )

    payload = result.output["diagnostic_result"]["payload"]

    assert payload["type"] == "regular"
    assert payload["size"] == 19
    refute String.contains?(inspect(payload), "secret-file-content")
  end

  test "http probe only checks configured local endpoints" do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, {_addr, port}} = :inet.sockname(socket)

    on_exit(fn -> :gen_tcp.close(socket) end)

    assert {:ok, result} =
             DiagnosticLane.execute(
               request("diagnostic.http_probe", %{"url" => "http://127.0.0.1:#{port}/health"}),
               []
             )

    payload = result.output["diagnostic_result"]["payload"]

    assert payload["host"] == "127.0.0.1"
    assert payload["port"] == port
    assert payload["reachable"] == true

    assert {:error, rejected} =
             DiagnosticLane.execute(
               request("diagnostic.http_probe", %{"url" => "https://example.com"}),
               []
             )

    assert rejected.output["diagnostic_result"]["status"] == "error"
    assert rejected.output["diagnostic_result"]["payload"]["reason"] == "probe_target_not_allowed"
  end

  test "time and output ceilings are enforced" do
    assert {:error, timeout} =
             DiagnosticLane.execute(
               request("diagnostic.echo", %{"message" => "slow", "delay_ms" => 5}),
               timeout_ms: 1
             )

    assert timeout.output["diagnostic_result"]["status"] == "timeout"

    assert {:error, oversized} =
             DiagnosticLane.execute(
               request("diagnostic.echo", %{"message" => String.duplicate("x", 128)}),
               max_output_bytes: 64
             )

    assert oversized.output["diagnostic_result"]["status"] == "error"
    assert oversized.output["diagnostic_result"]["payload"]["reason"] == "output_size_exceeded"
  end

  test "file write and credential operations are not available" do
    for operation <- ["diagnostic.write_file", "diagnostic.credentials"] do
      assert {:error, result} = DiagnosticLane.execute(request(operation), [])
      assert result.output["diagnostic_result"]["status"] == "error"
      assert result.output["diagnostic_result"]["payload"]["reason"] == "unsupported_operation"
    end
  end

  defp request(operation, payload \\ %{}) do
    ExecutionRequest.new!(
      execution_ref: "execution://diagnostic/test",
      lane_id: "diagnostic",
      operation: operation,
      payload: payload,
      provenance: ExecutionPlane.Provenance.direct_lower_lane_owner("diagnostic_lane_test")
    )
  end
end
