defmodule ExecutionPlaneHttpPackageTest do
  use ExUnit.Case, async: true

  test "runs a lower simulation through the HTTP package" do
    assert {:ok, result} =
             ExecutionPlane.HTTP.unary(
               %{
                 url: "https://example.test/widgets",
                 method: "GET"
               },
               route: %{
                 resolved_target: %{
                   "lower_simulation" => %{
                     "scenario_ref" => "http-package-smoke",
                     "status" => "succeeded",
                     "raw_payload" => %{
                       "status_code" => 200,
                       "headers" => %{"content-type" => "application/json"},
                       "body" => ~s({"ok":true})
                     },
                     "no_egress_policy" => %{
                       "policy_ref" => "policy://http-package-smoke",
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
                     }
                   }
                 }
               },
               lineage: %{
                 idempotency_key: "http-package-smoke"
               }
             )

    assert result.outcome.status == "succeeded"
    assert result.outcome.raw_payload["status_code"] == 200
  end
end
