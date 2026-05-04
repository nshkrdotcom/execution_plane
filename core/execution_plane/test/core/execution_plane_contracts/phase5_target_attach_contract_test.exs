defmodule ExecutionPlane.Contracts.Phase5TargetAttachContractTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Contracts.AttachGrant.V1, as: AttachGrant
  alias ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1, as: ExecutionIntentEnvelope
  alias ExecutionPlane.Contracts.TargetPosture.V1, as: TargetPosture

  @base_scope %{
    tenant_ref: "tenant://tenant-1",
    installation_ref: "installation://tenant-1/prod",
    workspace_ref: "workspace://tenant-1/runtime",
    project_ref: "project://tenant-1/ops",
    environment_ref: "environment://prod",
    principal_ref: "principal://operator/alice",
    resource_ref: "execution-resource://tenant-1/local-process/1",
    authority_packet_ref: "authority-packet://tenant-1/packet-1",
    permission_decision_ref: "permission-decision://tenant-1/decision-1",
    idempotency_key: "idem-phase5-target-attach",
    trace_id: "trace-phase5-target-attach",
    correlation_id: "correlation-phase5-target-attach",
    release_manifest_ref: "phase5-target-attach"
  }

  @target_ref "target://tenant-1/local-process/1"
  @attach_grant_ref "attach-grant://tenant-1/local-process/1"
  @credential_handle_ref "credential-handle://tenant-1/codex/handle-1"
  @provider_account_ref "provider-account://tenant-1/codex/main"
  @connector_instance_ref "connector-instance://tenant-1/codex/default"
  @target_posture_ref "target-posture://tenant-1/local-process/1"
  @no_egress_posture_ref "no-egress-posture://tenant-1/deny-external"
  @process_identity_ref "process-target-identity://tenant-1/local-process/1"
  @stream_identity_ref "stream-target-identity://tenant-1/stdout/1"

  test "target posture is bounded, ref-only, and authorizes matching attach grants" do
    posture = target_posture()
    grant = attach_grant()
    envelope = intent_envelope()

    assert posture.target_auth_posture == "materialize_on_attach"
    assert posture.target_auth_posture_ref == @target_posture_ref

    assert {:ok, evidence} = TargetPosture.authorize_attach(posture, grant, envelope)
    assert evidence.target_ref == @target_ref
    assert evidence.attach_grant_ref == @attach_grant_ref
    assert evidence.credential_handle_refs == [@credential_handle_ref]
    assert evidence.raw_material_present? == false

    rendered = inspect(evidence)
    refute String.contains?(rendered, "/tmp")
    refute String.contains?(rendered, "secret")
  end

  test "cross-target credential use rejects before materialization" do
    envelope =
      intent_envelope(%{
        target_ref: "target://tenant-1/other-process/1",
        process_target_identity_ref: "process-target-identity://tenant-1/other-process/1"
      })

    assert {:error, {:target_ref_mismatch, @target_ref, "target://tenant-1/other-process/1"}} =
             TargetPosture.authorize_attach(target_posture(), attach_grant(), envelope)
  end

  test "many credential handles require multi-handle target posture" do
    second_handle = "credential-handle://tenant-1/codex/handle-2"

    grant = attach_grant(%{credential_handle_refs: [@credential_handle_ref, second_handle]})
    envelope = intent_envelope(%{credential_handle_refs: [@credential_handle_ref, second_handle]})

    assert {:error, :target_multi_handle_not_permitted} =
             TargetPosture.authorize_attach(target_posture(), grant, envelope)

    multi_handle =
      target_posture(%{
        target_auth_posture: "multi_handle",
        multi_handle?: true,
        allowed_credential_handle_refs: [@credential_handle_ref, second_handle]
      })

    assert {:ok, evidence} = TargetPosture.authorize_attach(multi_handle, grant, envelope)
    assert evidence.credential_handle_refs == [@credential_handle_ref, second_handle]
  end

  test "no-credential and forbidden targets refuse credential materialization" do
    assert {:error, :target_posture_forbids_credentials} =
             target_posture(%{target_auth_posture: "no_credential"})
             |> TargetPosture.authorize_attach(attach_grant(), intent_envelope())

    assert {:error, :target_posture_forbidden} =
             target_posture(%{target_auth_posture: "forbidden"})
             |> TargetPosture.authorize_attach(attach_grant(), intent_envelope())
  end

  test "cleanup evidence removes materialized credential state and stays ref-only" do
    event = TargetPosture.cleanup_event(target_posture(), :stream_closed)

    assert event.cleanup_reason == "stream_closed"
    assert event.target_ref == @target_ref
    assert event.materialized_state_refs == []
    assert event.cleanup_refs == ["cleanup://tenant-1/local-process/1"]

    rendered = inspect(event)
    refute String.contains?(rendered, "raw_token")
    refute String.contains?(rendered, "secret")
  end

  defp target_posture(overrides \\ %{}) do
    %{
      tenant_ref: @base_scope.tenant_ref,
      target_ref: @target_ref,
      target_kind: "local_subprocess",
      target_auth_posture: "materialize_on_attach",
      target_auth_posture_ref: @target_posture_ref,
      boundary_session_id: "boundary-session-1",
      workspace_ref: @base_scope.workspace_ref,
      no_egress_posture_ref: @no_egress_posture_ref,
      process_target_identity_ref: @process_identity_ref,
      stream_target_identity_ref: @stream_identity_ref,
      allowed_provider_families: ["cli"],
      allowed_provider_account_refs: [@provider_account_ref],
      allowed_connector_instance_refs: [@connector_instance_ref],
      allowed_credential_handle_refs: [@credential_handle_ref],
      allowed_attach_grant_refs: [@attach_grant_ref],
      cleanup_refs: ["cleanup://tenant-1/local-process/1"],
      materialized_state_refs: ["materialized-credential://tenant-1/local-process/1"],
      multi_handle?: false
    }
    |> Map.merge(overrides)
    |> TargetPosture.new!()
  end

  defp attach_grant(overrides \\ %{}) do
    @base_scope
    |> Map.merge(%{
      attach_grant_ref: @attach_grant_ref,
      lease_ref: "credential-lease://tenant-1/codex/lease-1",
      target_ref: @target_ref,
      target_auth_posture: "materialize_on_attach",
      target_auth_posture_ref: @target_posture_ref,
      boundary_session_id: "boundary-session-1",
      no_egress_posture_ref: @no_egress_posture_ref,
      process_target_identity_ref: @process_identity_ref,
      stream_target_identity_ref: @stream_identity_ref,
      credential_handle_refs: [@credential_handle_ref],
      provider_account_refs: [@provider_account_ref],
      connector_instance_refs: [@connector_instance_ref],
      hazmat_resource_ref: "hazmat://runtime/tenant-1/local-process/stdio",
      grant_scope: %{
        "tenant_ref" => @base_scope.tenant_ref,
        "target_ref" => @target_ref,
        "workspace_ref" => @base_scope.workspace_ref,
        "credential_handle_refs" => [@credential_handle_ref],
        "capabilities" => ["session.attach", "stdio.read"]
      },
      expires_at: "2026-05-04T12:10:00Z",
      revocation_ref: "revocation://not-revoked"
    })
    |> Map.merge(overrides)
    |> AttachGrant.new!()
  end

  defp intent_envelope(overrides \\ %{}) do
    %{
      intent_id: "intent-phase5-target-attach",
      family: "process",
      protocol: "jsonrpc",
      trace_id: @base_scope.trace_id,
      idempotency_key: @base_scope.idempotency_key,
      boundary_session_id: "boundary-session-1",
      decision_id: "decision-1",
      lease_ref: "credential-lease://tenant-1/codex/lease-1",
      route_template_ref: "route-template://jsonrpc",
      credential_handle_refs: [@credential_handle_ref],
      target_ref: @target_ref,
      attach_grant_ref: @attach_grant_ref,
      target_auth_posture_ref: @target_posture_ref,
      workspace_ref: @base_scope.workspace_ref,
      no_egress_posture_ref: @no_egress_posture_ref,
      process_target_identity_ref: @process_identity_ref,
      stream_target_identity_ref: @stream_identity_ref,
      requested_capabilities: ["session.attach"]
    }
    |> Map.merge(overrides)
    |> ExecutionIntentEnvelope.new!()
  end
end
