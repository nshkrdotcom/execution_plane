defmodule ExecutionPlane.Contracts.LowerAuthorityRefsContractTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1, as: ExecutionIntentEnvelope
  alias ExecutionPlane.Testkit.ContractFixtures

  test "execution intent envelopes reject governed lower effects missing target posture refs" do
    base =
      ContractFixtures.execution_intent_envelope()
      |> Map.from_struct()
      |> Map.drop([
        :target_ref,
        :attach_grant_ref,
        :no_egress_posture_ref,
        :process_target_identity_ref,
        :stream_target_identity_ref
      ])

    assert_error_contains("target_ref is required", fn ->
      ExecutionIntentEnvelope.new!(base)
    end)

    assert_error_contains("attach_grant_ref is required", fn ->
      base
      |> Map.put(:target_ref, "target://tenant-1/local-process/1")
      |> ExecutionIntentEnvelope.new!()
    end)

    assert_error_contains("no_egress_posture_ref is required", fn ->
      base
      |> Map.put(:target_ref, "target://tenant-1/local-process/1")
      |> Map.put(:attach_grant_ref, "attach-grant://tenant-1/process/1")
      |> ExecutionIntentEnvelope.new!()
    end)
  end

  test "execution intent envelopes reject refs from the wrong authority layer" do
    base =
      ContractFixtures.execution_intent_envelope()
      |> Map.from_struct()

    assert_error_contains("target_ref must start with target://", fn ->
      base
      |> Map.put(:target_ref, "credential-handle://tenant-1/github/lease-1")
      |> ExecutionIntentEnvelope.new!()
    end)

    assert_error_contains("attach_grant_ref must start with attach-grant://", fn ->
      base
      |> Map.put(:attach_grant_ref, "system-authority://tenant-1/decision-1")
      |> ExecutionIntentEnvelope.new!()
    end)

    assert_error_contains("no_egress_posture_ref must start with no-egress-posture://", fn ->
      base
      |> Map.put(:no_egress_posture_ref, "provider-account://tenant-1/github/main")
      |> ExecutionIntentEnvelope.new!()
    end)
  end

  test "execution intent envelopes carry process and stream target identities as refs" do
    envelope =
      ExecutionIntentEnvelope.new!(%{
        intent_id: "intent-lower-1",
        family: "process",
        protocol: "jsonrpc",
        trace_id: "trace-lower-1",
        idempotency_key: "idem-lower-1",
        boundary_session_id: "boundary-session-1",
        decision_id: "decision-1",
        lease_ref: "credential-lease://tenant-1/provider/1",
        route_template_ref: "route-template://jsonrpc",
        credential_handle_refs: ["credential-handle://tenant-1/github/lease-1"],
        target_ref: "target://tenant-1/local-process/1",
        attach_grant_ref: "attach-grant://tenant-1/process/1",
        no_egress_posture_ref: "no-egress-posture://tenant-1/deny-external",
        process_target_identity_ref: "process-target-identity://tenant-1/local-process/1",
        stream_target_identity_ref: "stream-target-identity://tenant-1/stdout/1",
        requested_capabilities: ["session.attach"]
      })

    assert envelope.target_ref == "target://tenant-1/local-process/1"
    assert envelope.attach_grant_ref == "attach-grant://tenant-1/process/1"
    assert envelope.no_egress_posture_ref == "no-egress-posture://tenant-1/deny-external"

    assert envelope.process_target_identity_ref ==
             "process-target-identity://tenant-1/local-process/1"

    assert envelope.stream_target_identity_ref == "stream-target-identity://tenant-1/stdout/1"

    assert %{
             "target_ref" => "target://tenant-1/local-process/1",
             "attach_grant_ref" => "attach-grant://tenant-1/process/1",
             "no_egress_posture_ref" => "no-egress-posture://tenant-1/deny-external"
           } = ExecutionIntentEnvelope.dump(envelope)
  end

  defp assert_error_contains(fragment, fun) do
    error = assert_raise(ArgumentError, fun)

    assert Exception.message(error)
           |> String.downcase()
           |> String.contains?(String.downcase(fragment))
  end
end
