defmodule ExecutionPlane.JsonRpcTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.JsonRpc
  alias ExecutionPlane.Kernel.ExecutionResult

  test "call/2 executes unary jsonrpc over the minimal process lane" do
    script =
      write_script("""
      read payload
      printf '{"jsonrpc":"2.0","id":"attempt-jsonrpc-1","result":{"echo":%s}}\\n' "$payload"
      """)

    assert {:ok, %ExecutionResult{} = result} =
             JsonRpc.call(
               %{
                 command: script,
                 argv: [],
                 cwd: Path.dirname(script),
                 request: %{"method" => "session.start", "params" => %{"ok" => true}},
                 timeout_ms: 1_000
               },
               lineage: %{
                 attempt_ref: "attempt-jsonrpc-1",
                 idempotency_key: "idem-jsonrpc-1"
               }
             )

    assert result.outcome.status == "succeeded"
    assert result.outcome.raw_payload.response["id"] == "attempt-jsonrpc-1"
    assert result.outcome.raw_payload.response["result"]["echo"]["method"] == "session.start"
    assert result.plan.intent.envelope.requested_capabilities == ["jsonrpc.unary"]
  end

  defp write_script(body) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "execution_plane_jsonrpc_helper_#{System.unique_integer([:positive])}"
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
