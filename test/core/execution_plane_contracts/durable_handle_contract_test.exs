defmodule ExecutionPlane.DurableHandleContractTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Contracts.CredentialHandleRef.V1, as: CredentialHandleRef
  alias ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1, as: ExecutionIntentEnvelope

  test "credential handle refs require opaque handle-style refs" do
    assert_raise ArgumentError, ~r/opaque handle ref/, fn ->
      CredentialHandleRef.new!(%{
        handle_ref: "ghp_super_secret_value",
        kind: "oauth_bearer",
        audience: "github_api"
      })
    end

    assert %CredentialHandleRef{handle_ref: "credential-handle://tenant-1/github/lease-1"} =
             CredentialHandleRef.new!(%{
               handle_ref: "credential-handle://tenant-1/github/lease-1",
               kind: "oauth_bearer",
               audience: "github_api",
               expires_at: "2026-04-10T12:00:00Z",
               rotation_policy: "short_lived"
             })
  end

  test "execution intent envelopes reject raw secrets in credential_handle_refs" do
    assert_raise ArgumentError, ~r/opaque handle ref/, fn ->
      ExecutionIntentEnvelope.new!(%{
        intent_id: "intent-1",
        family: "process",
        protocol: "jsonrpc",
        idempotency_key: "idem-1",
        boundary_session_id: "boundary-session-1",
        decision_id: "decision-1",
        credential_handle_refs: ["sk-live-secret"],
        requested_capabilities: ["session.resume"]
      })
    end

    assert %ExecutionIntentEnvelope{
             credential_handle_refs: [
               "credential-handle://tenant-1/workload-identity/session-1",
               "urn:credential-handle:tenant-1:github:lease-1"
             ]
           } =
             ExecutionIntentEnvelope.new!(%{
               intent_id: "intent-2",
               family: "process",
               protocol: "jsonrpc",
               idempotency_key: "idem-2",
               boundary_session_id: "boundary-session-2",
               decision_id: "decision-2",
               credential_handle_refs: [
                 "credential-handle://tenant-1/workload-identity/session-1",
                 "urn:credential-handle:tenant-1:github:lease-1"
               ],
               requested_capabilities: ["session.attach"]
             })
  end
end
