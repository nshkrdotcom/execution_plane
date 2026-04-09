defmodule ExecutionPlane.MinimalLaneContractTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1, as: Envelope
  alias ExecutionPlane.Contracts.HttpExecutionIntent.V1, as: HttpExecutionIntent
  alias ExecutionPlane.Contracts.ProcessExecutionIntent.V1, as: ProcessExecutionIntent
  alias ExecutionPlane.Testkit.ContractFixtures

  test "HttpExecutionIntent.v1 accepts binary unary bodies" do
    intent =
      HttpExecutionIntent.new!(%{
        envelope: ContractFixtures.execution_intent_envelope(),
        request_shape: "request_response",
        stream_mode: "unary",
        headers: %{"content-type" => "application/json"},
        body: ~s({"ping":"pong"}),
        egress_surface: %{"surface_kind" => "https"},
        timeouts: %{"request_timeout_ms" => 750},
        retry_class: "safe_idempotent"
      })

    assert intent.body == ~s({"ping":"pong"})
  end

  test "ProcessExecutionIntent.v1 carries one-shot stdin and subprocess controls" do
    envelope =
      ContractFixtures.execution_intent_envelope()
      |> Map.from_struct()
      |> Map.put(:family, "process")
      |> Map.put(:protocol, "process")
      |> Envelope.new!()

    intent =
      ProcessExecutionIntent.new!(%{
        envelope: envelope,
        command: "sh",
        argv: ["-c", "printf ready"],
        env_projection: %{"ONLY_ME" => "set"},
        cwd: System.tmp_dir!(),
        stdin: "payload",
        clear_env: true,
        user: "runner",
        stdio_mode: "pipe",
        stderr_mode: "stdout",
        close_stdin: false,
        execution_surface: %{"surface_kind" => "local_subprocess"},
        shutdown_policy: %{"graceful_timeout_ms" => 50}
      })

    assert intent.stdin == "payload"
    assert intent.clear_env == true
    assert intent.user == "runner"
    assert intent.stderr_mode == "stdout"
    assert intent.close_stdin == false
  end
end
