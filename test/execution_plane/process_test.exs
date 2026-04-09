defmodule ExecutionPlane.ProcessTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Kernel.ExecutionResult
  alias ExecutionPlane.Process

  test "run/2 executes local subprocesses with stdin and subprocess controls" do
    stdin_path = temp_path!("stdin.txt")

    script =
      write_script("""
      cat > "#{stdin_path}"
      printf '%s\\n' "${ONLY_ME:-missing}"
      printf 'stderr-line\\n' >&2
      """)

    assert {:ok, %ExecutionResult{} = result} =
             Process.run(%{
               command: script,
               argv: [],
               cwd: Path.dirname(script),
               env: %{"ONLY_ME" => "env-ok"},
               clear_env: true,
               stdin: "payload-without-newline",
               stderr_mode: "separate",
               close_stdin: true,
               timeout_ms: 1_000
             })

    assert result.outcome.status == "succeeded"
    assert result.outcome.raw_payload.stdout == "env-ok\n"
    assert result.outcome.raw_payload.stderr == "stderr-line\n"
    assert result.outcome.raw_payload.invocation.env == %{"ONLY_ME" => "env-ok"}
    assert result.outcome.raw_payload.invocation.clear_env? == true
    assert result.outcome.metrics["duration_ms"] < 10_000
    assert result.plan.intent.stdin == "payload-without-newline"
    assert result.plan.intent.stderr_mode == "separate"
    assert result.plan.intent.close_stdin == true
    assert File.read!(stdin_path) == "payload-without-newline"
  end

  defp write_script(body) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "execution_plane_process_helper_#{System.unique_integer([:positive])}"
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

  defp temp_path!(name) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "execution_plane_process_helper_tmp_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)

    on_exit(fn ->
      File.rm_rf!(dir)
    end)

    Path.join(dir, name)
  end
end
