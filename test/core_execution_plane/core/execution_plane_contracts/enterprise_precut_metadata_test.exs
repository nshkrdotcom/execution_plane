defmodule ExecutionPlane.Contracts.EnterprisePrecutMetadataTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.{
    ActivitySideEffectIdempotency,
    AttachGrantContract,
    CancellationMetadata,
    ExecutionActivityMetadata,
    HeartbeatMetadata,
    RuntimeEvidenceRef,
    StreamLeaseContract
  }

  @modules [
    ActivitySideEffectIdempotency,
    AttachGrantContract,
    CancellationMetadata,
    ExecutionActivityMetadata,
    HeartbeatMetadata,
    RuntimeEvidenceRef,
    StreamLeaseContract
  ]

  test "loads every M24 execution-plane contract" do
    for module <- @modules do
      assert Code.ensure_loaded?(module), "#{inspect(module)} is not compiled"
    end
  end

  test "execution activity metadata carries authority, workflow, lower, and trace refs" do
    assert {:ok, metadata} =
             ExecutionActivityMetadata.new(%{
               tenant_ref: "tenant-acme",
               actor_ref: "principal-operator",
               resource_ref: "resource-work-1",
               workflow_ref: "wf-110",
               activity_call_ref: "act-112",
               lower_run_ref: "lower-112",
               target_ref: "target-1",
               authority_packet_ref: "authpkt-112",
               permission_decision_ref: "decision-112",
               trace_id: "trace-112",
               idempotency_key: "idem-exec-112",
               runtime_family: "beam",
               timeout_policy: "bounded",
               heartbeat_policy: "lease_bound"
             })

    assert metadata.contract_name == "ExecutionPlane.ExecutionActivityMetadata.v1"
  end

  test "execution side-effect activity dedupes by intent id and idempotency key" do
    assert ActivitySideEffectIdempotency.contract_name() ==
             "ExecutionPlane.ActivitySideEffectIdempotency.v1"

    assert ActivitySideEffectIdempotency.idempotency_scope() == "intent_id + idempotency_key"

    assert {:ok, first} =
             ActivitySideEffectIdempotency.new(execution_side_effect_attrs())

    assert first.lease_ref == "lease-100"
    assert first.heartbeat_policy == "lease_bound"
    assert ActivitySideEffectIdempotency.side_effect_key(first) == {"intent-100", "idem-exec-100"}

    assert {:ok, retry} =
             ActivitySideEffectIdempotency.new(
               execution_side_effect_attrs(%{activity_call_ref: "act-100-retry"})
             )

    assert ActivitySideEffectIdempotency.same_retry_scope?(first, retry)

    assert {:error, {:missing_required_fields, missing}} =
             execution_side_effect_attrs()
             |> Map.drop([:intent_id, :idempotency_key, :lease_ref])
             |> ActivitySideEffectIdempotency.new()

    assert :intent_id in missing
    assert :idempotency_key in missing
    assert :lease_ref in missing
  end

  test "attach grants and stream leases are lease-bound, traceable, and revocable" do
    assert {:ok, attach} =
             AttachGrantContract.new(%{
               attach_grant_id: "attach-114",
               tenant_ref: "tenant-acme",
               principal_ref: "principal-operator",
               resource_ref: "resource-work-1",
               stream_ref: "stream-114",
               lease_ref: "lease-114",
               expires_at: "2026-04-18T00:00:00Z",
               revocation_state: "active",
               authority_packet_ref: "authpkt-114",
               permission_decision_ref: "decision-114",
               trace_id: "trace-114"
             })

    assert attach.revocation_state == "active"

    assert {:ok, _lease} =
             StreamLeaseContract.new(%{
               stream_ref: "stream-114",
               tenant_ref: "tenant-acme",
               resource_ref: "resource-work-1",
               lease_ref: "lease-114",
               epoch_ref: "epoch-1",
               trace_id: "trace-114",
               revocation_state: "active"
             })
  end

  test "cancellation, heartbeat, and runtime evidence keep workflow and lower refs" do
    assert {:ok, _cancel} =
             CancellationMetadata.new(%{
               cancellation_id: "cancel-114",
               tenant_ref: "tenant-acme",
               actor_ref: "principal-operator",
               resource_ref: "resource-work-1",
               workflow_ref: "wf-110",
               activity_call_ref: "act-112",
               lower_run_ref: "lower-112",
               authority_packet_ref: "authpkt-114",
               permission_decision_ref: "decision-114",
               trace_id: "trace-114",
               idempotency_key: "idem-cancel-114"
             })

    assert {:ok, _heartbeat} =
             HeartbeatMetadata.new(%{
               heartbeat_id: "heartbeat-112",
               tenant_ref: "tenant-acme",
               resource_ref: "resource-work-1",
               workflow_ref: "wf-110",
               activity_call_ref: "act-112",
               lower_run_ref: "lower-112",
               trace_id: "trace-112",
               lease_ref: "lease-112"
             })

    assert {:ok, _evidence} =
             RuntimeEvidenceRef.new(%{
               runtime_evidence_ref: "runtime-evidence-112",
               tenant_ref: "tenant-acme",
               resource_ref: "resource-work-1",
               lower_run_ref: "lower-112",
               trace_id: "trace-112",
               payload_hash: String.duplicate("a", 64),
               redaction_posture: "operator_summary"
             })
  end

  defp execution_side_effect_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        tenant_ref: "tenant-acme",
        actor_ref: "principal-operator",
        resource_ref: "resource-work-1",
        workflow_ref: "wf-100",
        activity_call_ref: "act-100",
        lower_run_ref: "lower-100",
        intent_id: "intent-100",
        idempotency_key: "idem-exec-100",
        authority_packet_ref: "authpkt-100",
        permission_decision_ref: "decision-100",
        trace_id: "trace-100",
        lease_ref: "lease-100",
        lease_evidence_ref: "evidence-100",
        heartbeat_policy: "lease_bound",
        timeout_policy: "bounded",
        retry_policy: "safe_idempotent",
        runtime_family: "beam",
        side_effect_ref: "side-effect-100",
        release_manifest_ref: "phase4-v6-milestone29"
      },
      overrides
    )
  end
end
