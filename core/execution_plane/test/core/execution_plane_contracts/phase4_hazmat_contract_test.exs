defmodule ExecutionPlane.Contracts.Phase4HazmatContractTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Contracts.AttachGrant.V1, as: AttachGrant
  alias ExecutionPlane.Contracts.NoBypassScan.V1, as: NoBypassScan
  alias ExecutionPlane.Contracts.StreamAttachRevocation.V1, as: StreamAttachRevocation
  alias ExecutionPlane.Contracts.StreamBackpressure.V1, as: StreamBackpressure
  alias ExecutionPlane.Contracts.WorkerBudget.V1, as: WorkerBudget

  @base_scope %{
    tenant_ref: "tenant://expense",
    installation_ref: "installation://expense/prod",
    workspace_ref: "workspace://expense/runtime",
    project_ref: "project://expense/ops",
    environment_ref: "environment://prod",
    principal_ref: "principal://operator/alice",
    resource_ref: "execution-resource://container/expense-runner",
    authority_packet_ref: "authority-packet://phase4/packet-1",
    permission_decision_ref: "permission-decision://phase4/decision-1",
    idempotency_key: "idem-execution-plane-phase4",
    trace_id: "trace-execution-plane-phase4",
    correlation_id: "correlation-execution-plane-phase4",
    release_manifest_ref: "phase4-v6-milestone6"
  }

  describe "ExecutionPlane.AttachGrant.v1" do
    test "requires tenant, authority, trace, lease, resource, and revocation scope" do
      grant =
        @base_scope
        |> Map.merge(%{
          attach_grant_ref: "attach-grant://expense/stream/1",
          lease_ref: "lease://expense/stream/1",
          hazmat_resource_ref: "hazmat://runtime/expense/stdio",
          grant_scope: %{
            "tenant_ref" => @base_scope.tenant_ref,
            "resource_ref" => @base_scope.resource_ref,
            "capabilities" => ["stream.attach", "stdio.read"]
          },
          expires_at: "2026-04-18T22:00:00Z",
          revocation_ref: "revocation://not-revoked"
        })
        |> AttachGrant.new!()

      assert grant.contract_version == "ExecutionPlane.AttachGrant.v1"
      assert grant.tenant_ref == @base_scope.tenant_ref
      assert grant.attach_grant_ref == "attach-grant://expense/stream/1"
      assert grant.grant_scope["capabilities"] == ["stream.attach", "stdio.read"]
      assert AttachGrant.dump(grant)["lease_ref"] == "lease://expense/stream/1"
    end

    test "rejects the legacy narrow attach grant shape" do
      assert {:error, %ArgumentError{message: message}} =
               AttachGrant.new(%{
                 boundary_session_id: "boundary-session-1",
                 attach_mode: "read_write",
                 attach_surface: %{"surface_kind" => "stdio"},
                 working_directory: "/tmp/workspace",
                 expires_at: "2026-04-18T22:00:00Z",
                 granted_capabilities: ["attach.read"]
               })

      assert message =~ "principal_ref or system_actor_ref"
    end
  end

  test "ExecutionPlane.StreamBackpressure.v1 requires deterministic termination evidence" do
    event =
      @base_scope
      |> Map.merge(%{
        stream_ref: "stream://expense/runtime/1",
        budget_ref: "budget://tenant/expense/stream",
        pressure_class: "hard_pressure",
        termination_reason: "budget_exhausted",
        last_heartbeat_at: "2026-04-18T21:55:00Z",
        diagnostics_ref: "diagnostics://stream/1"
      })
      |> StreamBackpressure.new!()

    assert event.contract_version == "ExecutionPlane.StreamBackpressure.v1"
    assert event.pressure_class == "hard_pressure"
    assert StreamBackpressure.dump(event)["termination_reason"] == "budget_exhausted"
  end

  test "ExecutionPlane.WorkerBudget.v1 rejects invalid load and records shed reason" do
    assert {:error, %ArgumentError{message: message}} =
             WorkerBudget.new(
               @base_scope
               |> Map.merge(%{
                 worker_pool_ref: "worker-pool://expense/default",
                 budget_ref: "budget://tenant/expense/workers",
                 queue_ref: "queue://expense/runtime",
                 current_load: -1,
                 admission_decision_ref: "admission://decision/1",
                 shed_reason: "tenant_budget_exhausted"
               })
             )

    assert message =~ "current_load"

    accepted =
      @base_scope
      |> Map.merge(%{
        worker_pool_ref: "worker-pool://expense/default",
        budget_ref: "budget://tenant/expense/workers",
        queue_ref: "queue://expense/runtime",
        current_load: 42,
        admission_decision_ref: "admission://decision/1",
        shed_reason: "tenant_budget_exhausted"
      })
      |> WorkerBudget.new!()

    assert accepted.contract_version == "ExecutionPlane.WorkerBudget.v1"
    assert WorkerBudget.dump(accepted)["current_load"] == 42
  end

  test "ExecutionPlane.StreamAttachRevocation.v1 terminates stale stream grants" do
    event =
      @base_scope
      |> Map.merge(%{
        stream_ref: "stream://expense/runtime/1",
        attach_grant_ref: "attach-grant://expense/stream/1",
        lease_ref: "lease://expense/stream/1",
        revocation_ref: "revocation://lease/1",
        termination_ref: "termination://stream/1",
        last_event_position: 17
      })
      |> StreamAttachRevocation.new!()

    assert event.contract_version == "ExecutionPlane.StreamAttachRevocation.v1"
    assert event.last_event_position == 17

    assert {:error, %ArgumentError{message: message}} =
             event
             |> Map.from_struct()
             |> Map.put(:last_event_position, -1)
             |> StreamAttachRevocation.new()

    assert message =~ "last_event_position"
  end

  test "ExecutionPlane.NoBypassScan.v1 fails closed on forbidden hazmat imports" do
    clear =
      @base_scope
      |> Map.merge(%{
        scan_ref: "scan://execution-plane/no-bypass/clear",
        caller_repo: "app_kit",
        forbidden_module: "ExecutionPlane",
        required_facade: "AppKit boundary or Mezzanine activity facade",
        violation_ref: "violation://none",
        scan_status: "clear",
        checked_paths: ["lib/app_kit"],
        violations: []
      })
      |> NoBypassScan.new!()

    assert clear.contract_version == "ExecutionPlane.NoBypassScan.v1"
    assert NoBypassScan.dump(clear)["scan_status"] == "clear"

    assert {:error, %ArgumentError{message: message}} =
             NoBypassScan.new(%{
               Map.from_struct(clear)
               | scan_status: "clear",
                 violations: [
                   %{
                     "path" => "lib/product.ex",
                     "line" => 12,
                     "forbidden_module" => "ExecutionPlane",
                     "required_facade" => "AppKit boundary"
                   }
                 ]
             })

    assert message =~ "clear no-bypass scan"
  end
end
