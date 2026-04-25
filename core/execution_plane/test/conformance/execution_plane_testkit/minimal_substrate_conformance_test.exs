defmodule ExecutionPlane.Testkit.MinimalSubstrateConformanceTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Contracts.ExecutionEvent.V1, as: ExecutionEvent
  alias ExecutionPlane.Contracts.ExecutionRoute.V1, as: ExecutionRoute
  alias ExecutionPlane.Contracts.Failure
  alias ExecutionPlane.Contracts.HttpExecutionIntent.V1, as: HttpExecutionIntent
  alias ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1, as: JsonRpcExecutionIntent
  alias ExecutionPlane.Contracts.ProcessExecutionIntent.V1, as: ProcessExecutionIntent
  alias ExecutionPlane.Kernel
  alias ExecutionPlane.Kernel.ExecutionResult
  alias ExecutionPlane.Testkit.ContractFixtures
  alias ExecutionPlane.TestSupport.SimpleHTTPServer

  test "kernel executes unary http on the final contracts and emits raw facts" do
    server =
      SimpleHTTPServer.start(self(), fn request ->
        assert request.method == "POST"
        assert request.path == "/echo"
        assert request.body == ~s({"ping":"pong"})
        {201, [{"content-type", "application/json"}], ~s({"ok":true})}
      end)

    on_exit(fn -> Process.exit(server.pid, :kill) end)

    intent =
      ContractFixtures.http_execution_intent()
      |> Map.from_struct()
      |> Map.put(:timeouts, %{"request_timeout_ms" => 750})
      |> HttpExecutionIntent.new!()

    route =
      ContractFixtures.http_execution_route()
      |> Map.from_struct()
      |> Map.put(:resolved_target, %{"url" => server.url <> "/echo", "method" => "POST"})
      |> Map.put(:resolved_budget, %{"timeout_ms" => 1_500})
      |> ExecutionRoute.new!()

    assert {:ok, %ExecutionResult{} = result} =
             Kernel.execute(intent, route, emit: &send(self(), {:kernel_event, &1}))

    assert result.plan.timeout_ms == 750
    assert Enum.map(result.events, & &1.event_type) == ["dispatch.started", "dispatch.completed"]
    assert result.outcome.status == "succeeded"
    assert result.outcome.family == "http"
    assert result.outcome.raw_payload.status_code == 201
    assert result.outcome.raw_payload.body == ~s({"ok":true})
    assert result.outcome.lineage.trace_id == route.lineage.trace_id
    assert result.outcome.lineage.request_id == route.lineage.request_id

    assert_receive {:simple_http_request, %{headers: headers}}, 1_000
    assert headers["content-type"] == "application/json"

    assert_receive {:kernel_event, %ExecutionEvent{event_type: "dispatch.started"}}, 1_000
    assert_receive {:kernel_event, %ExecutionEvent{event_type: "dispatch.completed"}}, 1_000
  end

  test "kernel executes basic local process runs and preserves lineage into the outcome" do
    script =
      write_script("""
      printf 'stdout-line\\n'
      printf 'stderr-line\\n' >&2
      exit 3
      """)

    intent =
      ContractFixtures.process_execution_intent()
      |> Map.from_struct()
      |> Map.put(:command, script)
      |> Map.put(:argv, [])
      |> Map.put(:cwd, Path.dirname(script))
      |> ProcessExecutionIntent.new!()

    route =
      ContractFixtures.process_execution_route()
      |> Map.from_struct()
      |> Map.put(:resolved_budget, %{"timeout_ms" => 1_000})
      |> ExecutionRoute.new!()

    assert {:error, %ExecutionResult{} = result} = Kernel.execute(intent, route)

    assert result.outcome.status == "failed"
    assert result.outcome.family == "process"
    assert result.outcome.raw_payload.stdout == "stdout-line\n"
    assert result.outcome.raw_payload.stderr == "stderr-line\n"
    assert result.outcome.raw_payload.exit.code == 3
    assert result.outcome.failure == nil
    assert result.outcome.lineage.trace_id == route.lineage.trace_id
    assert result.outcome.lineage.route_id == route.route_id
  end

  test "kernel executes unary jsonrpc over the process runtime" do
    script =
      write_script("""
      read payload
      printf '{"jsonrpc":"2.0","id":"attempt://1","result":{"echo":%s}}\\n' "$payload"
      """)

    intent =
      ContractFixtures.jsonrpc_execution_intent()
      |> Map.from_struct()
      |> Map.put(:request, %{"method" => "session.start", "params" => %{"ok" => true}})
      |> JsonRpcExecutionIntent.new!()

    route =
      ContractFixtures.jsonrpc_execution_route()
      |> Map.from_struct()
      |> Map.put(:resolved_target, %{
        "command" => script,
        "argv" => [],
        "cwd" => Path.dirname(script),
        "execution_surface" => %{"surface_kind" => "local_subprocess"}
      })
      |> ExecutionRoute.new!()

    assert {:ok, %ExecutionResult{} = result} = Kernel.execute(intent, route)

    assert result.outcome.status == "succeeded"
    assert result.outcome.family == "process"
    assert result.outcome.raw_payload.response["id"] == "attempt://1"
    assert result.outcome.raw_payload.response["result"]["echo"]["method"] == "session.start"
    assert result.outcome.lineage.trace_id == route.lineage.trace_id
    assert Enum.map(result.events, & &1.event_type) == ["dispatch.started", "dispatch.completed"]
  end

  test "kernel classifies timeouts as raw-fact failures with partial execution context" do
    script =
      write_script("""
      printf 'tick'
      sleep 1
      """)

    intent =
      ContractFixtures.process_execution_intent()
      |> Map.from_struct()
      |> Map.put(:command, script)
      |> Map.put(:argv, [])
      |> Map.put(:cwd, Path.dirname(script))
      |> ProcessExecutionIntent.new!()

    route =
      ContractFixtures.process_execution_route()
      |> Map.from_struct()
      |> Map.put(:resolved_budget, %{"timeout_ms" => 25})
      |> ExecutionRoute.new!()

    assert {:error, %ExecutionResult{} = result} = Kernel.execute(intent, route)

    assert %Failure{} = result.outcome.failure
    assert result.outcome.failure.failure_class == :timeout
    assert result.outcome.failure.durable_truth_relevance == :raw_fact_only
    assert result.outcome.raw_payload.stdout == "tick"
    assert List.last(result.events).event_type == "dispatch.failed"
  end

  defp write_script(body) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "execution_plane_wave2_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    path = Path.join(dir, "fixture.sh")

    File.write!(path, """
    #!/usr/bin/env bash
    set -euo pipefail
    #{body}
    """)

    File.chmod!(path, 0o755)

    on_exit(fn ->
      File.rm_rf!(dir)
    end)

    path
  end
end
