defmodule ExecutionPlane.LowerSimulationTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Contracts.ExecutionRoute.V1, as: ExecutionRoute
  alias ExecutionPlane.Contracts.HttpExecutionIntent.V1, as: HttpExecutionIntent
  alias ExecutionPlane.Contracts.ProcessExecutionIntent.V1, as: ProcessExecutionIntent
  alias ExecutionPlane.Kernel
  alias ExecutionPlane.Kernel.ExecutionResult
  alias ExecutionPlane.Testkit.ContractFixtures

  test "http lower simulation returns normal raw payload plus bounded evidence without egress" do
    intent =
      ContractFixtures.http_execution_intent()
      |> Map.from_struct()
      |> Map.put(:body, %{"prompt" => "raw input is hashed only in evidence"})
      |> HttpExecutionIntent.new!()

    route =
      ContractFixtures.http_execution_route()
      |> Map.from_struct()
      |> Map.put(:resolved_target, %{
        "url" => "http://127.0.0.1:1/should-not-egress",
        "method" => "POST",
        "lower_simulation" => %{
          "scenario_ref" => "lower-simulation://http/success",
          "side_effect_policy" => "deny_external_egress",
          "no_egress_policy" => no_egress_policy(),
          "raw_payload" => %{
            "status_code" => 200,
            "headers" => %{"content-type" => "application/json"},
            "body" => ~s({"provider_wire":true})
          }
        }
      })
      |> ExecutionRoute.new!()

    assert {:ok, %ExecutionResult{} = result} = Kernel.execute(intent, route)

    assert result.outcome.status == "succeeded"
    assert result.outcome.family == "http"
    assert result.outcome.raw_payload["status_code"] == 200
    assert result.outcome.raw_payload["body"] == ~s({"provider_wire":true})

    assert [artifact] = result.outcome.artifacts
    assert artifact["kind"] == "lower_simulation_evidence"
    evidence = artifact["evidence"]

    assert evidence["scenario_ref"] == "lower-simulation://http/success"
    assert evidence["side_effect_policy"] == "deny_external_egress"
    assert evidence["side_effect_result"] == "not_attempted"
    assert evidence["raw_payload_shape"] == ["body", "headers", "status_code"]
    assert evidence["input_fingerprint"]["sha256"] =~ "sha256:"
    assert evidence["output_fingerprint"]["sha256"] =~ "sha256:"
    refute Map.has_key?(evidence["input_fingerprint"], "body")
    refute Map.has_key?(evidence["output_fingerprint"], "body")

    assert artifact["no_egress_policy_ref"] == "no-egress-policy://execution-plane/lower/v1"

    assert Enum.sort(artifact["negative_evidence_refs"]) == [
             "attempted_raw_external_saas_write_path",
             "attempted_unregistered_provider_route"
           ]
  end

  test "invalid http lower simulation fails before egress" do
    route =
      ContractFixtures.http_execution_route()
      |> Map.from_struct()
      |> Map.put(:resolved_target, %{
        "url" => "http://127.0.0.1:1/should-not-egress",
        "lower_simulation" => %{
          "raw_payload" => %{"status_code" => 200, "headers" => %{}, "body" => "ignored"}
        }
      })
      |> ExecutionRoute.new!()

    assert {:error, %ExecutionResult{} = result} =
             Kernel.execute(ContractFixtures.http_execution_intent(), route)

    assert result.outcome.failure.failure_class == :route_unresolved
    assert result.outcome.raw_payload.side_effect_result == "blocked_before_dispatch"
    assert result.outcome.artifacts == []
  end

  test "process lower simulation skips process spawn and preserves process raw payload" do
    intent =
      ContractFixtures.process_execution_intent()
      |> Map.from_struct()
      |> Map.put(:command, "execution-plane-prelim-command-must-not-exist")
      |> Map.put(:stdin, "raw stdin is hashed only in evidence")
      |> ProcessExecutionIntent.new!()

    route =
      ContractFixtures.process_execution_route()
      |> Map.from_struct()
      |> Map.put(:resolved_target, %{
        "target_id" => "process-simulation",
        "lower_simulation" => %{
          "scenario_ref" => "lower-simulation://process/success",
          "side_effect_policy" => "deny_process_spawn",
          "no_egress_policy" => no_egress_policy(),
          "raw_payload" => %{
            "stdout" => ~s({"jsonrpc":"2.0","result":{"ok":true}}),
            "stderr" => "",
            "exit" => %{"code" => 0}
          }
        }
      })
      |> ExecutionRoute.new!()

    assert {:ok, %ExecutionResult{} = result} = Kernel.execute(intent, route)

    assert result.outcome.status == "succeeded"
    assert result.outcome.family == "process"
    assert result.outcome.raw_payload["stdout"] =~ ~s("ok":true)

    assert [artifact] = result.outcome.artifacts
    assert artifact["evidence"]["side_effect_policy"] == "deny_process_spawn"
    assert artifact["evidence"]["side_effect_result"] == "not_attempted"
    refute Map.has_key?(artifact["evidence"]["input_fingerprint"], "stdin")
    assert artifact["no_egress_policy_ref"] == "no-egress-policy://execution-plane/lower/v1"
  end

  test "invalid process lower simulation no-egress policy fails before process spawn" do
    intent =
      ContractFixtures.process_execution_intent()
      |> Map.from_struct()
      |> Map.put(:command, "execution-plane-prelim-command-must-not-exist")
      |> ProcessExecutionIntent.new!()

    route =
      ContractFixtures.process_execution_route()
      |> Map.from_struct()
      |> Map.put(:resolved_target, %{
        "target_id" => "process-simulation",
        "lower_simulation" => %{
          "scenario_ref" => "lower-simulation://process/invalid",
          "side_effect_policy" => "deny_external_egress",
          "no_egress_policy" =>
            no_egress_policy(%{
              "required_negative_evidence" => ["attempted_unregistered_provider_route"]
            }),
          "raw_payload" => %{"stdout" => "", "stderr" => "", "exit" => %{"code" => 0}}
        }
      })
      |> ExecutionRoute.new!()

    assert {:error, %ExecutionResult{} = result} = Kernel.execute(intent, route)

    assert result.outcome.failure.failure_class == :route_unresolved
    assert result.outcome.raw_payload.side_effect_result == "blocked_before_dispatch"
    assert result.outcome.raw_payload.error =~ "required_negative_evidence"
  end

  defp no_egress_policy(overrides \\ %{}) do
    Map.merge(
      %{
        "policy_ref" => "no-egress-policy://execution-plane/lower/v1",
        "owner_repo" => "execution_plane",
        "mode" => "deny",
        "enforcement_boundary" => "lower_runtime",
        "denied_surfaces" => %{
          "external_egress" => "deny",
          "process_spawn" => "deny",
          "unregistered_provider_route" => "deny",
          "raw_external_saas_write_path" => "deny"
        },
        "required_negative_evidence" => [
          "attempted_unregistered_provider_route",
          "attempted_raw_external_saas_write_path"
        ]
      },
      overrides
    )
  end
end
