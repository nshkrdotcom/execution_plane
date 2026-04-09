defmodule ExecutionPlane.Testkit.ContractFixtures do
  @moduledoc """
  Wave 1 fixtures for the frozen contract packet.
  """

  alias ExecutionPlane.Contracts.AttachGrant.V1, as: AttachGrant
  alias ExecutionPlane.Contracts.AuthorityDecision.V1, as: AuthorityDecision
  alias ExecutionPlane.Contracts.BoundarySessionDescriptor.V1, as: BoundarySessionDescriptor
  alias ExecutionPlane.Contracts.CredentialHandleRef.V1, as: CredentialHandleRef
  alias ExecutionPlane.Contracts.ExecutionEvent.V1, as: ExecutionEvent
  alias ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1, as: ExecutionIntentEnvelope
  alias ExecutionPlane.Contracts.ExecutionOutcome.V1, as: ExecutionOutcome
  alias ExecutionPlane.Contracts.ExecutionRoute.V1, as: ExecutionRoute
  alias ExecutionPlane.Contracts.Failure
  alias ExecutionPlane.Contracts.HttpExecutionIntent.V1, as: HttpExecutionIntent
  alias ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1, as: JsonRpcExecutionIntent
  alias ExecutionPlane.Contracts.ProcessExecutionIntent.V1, as: ProcessExecutionIntent

  @spec authority_decision() :: AuthorityDecision.t()
  def authority_decision do
    AuthorityDecision.new!(%{
      decision_id: "decision-1",
      tenant_id: "tenant-1",
      request_id: "request-1",
      policy_version: "policy-2026-04-08",
      boundary_class: "workspace",
      trust_profile: "trusted_internal",
      approval_profile: "manual",
      egress_profile: "restricted",
      workspace_profile: "ephemeral_repo",
      resource_profile: "standard",
      decision_hash: "hash-1",
      extensions: %{"brain" => %{"wave" => 1}}
    })
  end

  @spec boundary_session_descriptor() :: BoundarySessionDescriptor.t()
  def boundary_session_descriptor do
    BoundarySessionDescriptor.new!(%{
      boundary_session_id: "boundary-session-1",
      decision_id: authority_decision().decision_id,
      session_status: "active",
      attach_state: "attachable",
      workspace_ref: "workspace://repo-1",
      artifact_refs: ["artifact://plan-1"],
      lease_refs: ["lease://1"],
      approval_refs: ["approval://1"],
      policy_echo: %{"approval_profile" => "manual"},
      extensions: %{"spine" => %{"route_owner" => "jido_integration"}}
    })
  end

  @spec execution_intent_envelope() :: ExecutionIntentEnvelope.t()
  def execution_intent_envelope do
    ExecutionIntentEnvelope.new!(%{
      intent_id: "intent-1",
      family: "http",
      protocol: "http",
      idempotency_key: "idem-1",
      boundary_session_id: boundary_session_descriptor().boundary_session_id,
      decision_id: authority_decision().decision_id,
      lease_ref: "lease://1",
      route_template_ref: "route-template://http",
      credential_handle_refs: ["cred://1"],
      attempt_ref: "attempt://1",
      deadline_at: "2026-04-10T12:00:00Z",
      cancellation_ref: "cancel://1",
      requested_capabilities: ["http.unary"],
      extensions: %{"wave" => 1}
    })
  end

  @spec http_execution_intent() :: HttpExecutionIntent.t()
  def http_execution_intent do
    HttpExecutionIntent.new!(%{
      envelope: execution_intent_envelope(),
      request_shape: "request_response",
      stream_mode: "unary",
      headers: %{"accept" => "application/json"},
      body: %{"ping" => "pong"},
      egress_surface: %{"surface_kind" => "https"},
      timeouts: %{"request_timeout_ms" => 5_000},
      retry_class: "safe_idempotent"
    })
  end

  @spec process_execution_intent() :: ProcessExecutionIntent.t()
  def process_execution_intent do
    ProcessExecutionIntent.new!(%{
      envelope:
        execution_intent_envelope()
        |> Map.from_struct()
        |> Map.put(:family, "process")
        |> Map.put(:protocol, "process")
        |> ExecutionIntentEnvelope.new!(),
      command: "codex",
      argv: ["exec", "--json"],
      env_projection: %{"CODEX_ENV" => "test"},
      cwd: "/tmp/workspace",
      stdio_mode: "pty",
      execution_surface: %{"surface_kind" => "local_subprocess"},
      shutdown_policy: %{"graceful_timeout_ms" => 2_000}
    })
  end

  @spec jsonrpc_execution_intent() :: JsonRpcExecutionIntent.t()
  def jsonrpc_execution_intent do
    JsonRpcExecutionIntent.new!(%{
      envelope:
        execution_intent_envelope()
        |> Map.from_struct()
        |> Map.put(:family, "process")
        |> Map.put(:protocol, "jsonrpc")
        |> ExecutionIntentEnvelope.new!(),
      transport_binding: %{"mode" => "stdio"},
      protocol_schema: %{"schema" => "jsonrpc-2.0"},
      request: %{"method" => "session.start"},
      session_policy: %{"attachable" => true}
    })
  end

  @spec execution_route() :: ExecutionRoute.t()
  def execution_route do
    http_execution_route()
  end

  @spec http_execution_route() :: ExecutionRoute.t()
  def http_execution_route do
    ExecutionRoute.new!(%{
      route_id: "route-1",
      family: "http",
      protocol: "http",
      transport_family: "http",
      placement_family: "local",
      resolved_target: %{"target_id" => "loopback"},
      resolved_budget: %{"timeout_ms" => 5_000},
      lineage: lineage(route_id: "route-1")
    })
  end

  @spec process_execution_route() :: ExecutionRoute.t()
  def process_execution_route do
    ExecutionRoute.new!(%{
      route_id: "route-process-1",
      family: "process",
      protocol: "process",
      transport_family: "process",
      placement_family: "local",
      resolved_target: %{"target_id" => "local-runtime"},
      resolved_budget: %{"timeout_ms" => 5_000},
      lineage: lineage(route_id: "route-process-1")
    })
  end

  @spec jsonrpc_execution_route() :: ExecutionRoute.t()
  def jsonrpc_execution_route do
    ExecutionRoute.new!(%{
      route_id: "route-jsonrpc-1",
      family: "process",
      protocol: "jsonrpc",
      transport_family: "process",
      placement_family: "local",
      resolved_target: %{
        "target_id" => "local-jsonrpc",
        "execution_surface" => %{"surface_kind" => "local_subprocess"}
      },
      resolved_budget: %{"timeout_ms" => 5_000},
      lineage: lineage(route_id: "route-jsonrpc-1")
    })
  end

  @spec attach_grant() :: AttachGrant.t()
  def attach_grant do
    AttachGrant.new!(%{
      boundary_session_id: boundary_session_descriptor().boundary_session_id,
      attach_mode: "read_write",
      attach_surface: %{"surface_kind" => "stdio"},
      working_directory: "/tmp/workspace",
      expires_at: "2026-04-10T12:10:00Z",
      granted_capabilities: ["attach.read", "attach.write"]
    })
  end

  @spec credential_handle_ref() :: CredentialHandleRef.t()
  def credential_handle_ref do
    CredentialHandleRef.new!(%{
      handle_ref: "cred://1",
      kind: "oauth_bearer",
      audience: "github_api",
      expires_at: "2026-04-10T12:00:00Z",
      rotation_policy: "short_lived"
    })
  end

  @spec execution_event() :: ExecutionEvent.t()
  def execution_event do
    ExecutionEvent.new!(%{
      event_id: "event-1",
      route_id: http_execution_route().route_id,
      event_type: "transport.connected",
      timestamp: "2026-04-10T11:55:00Z",
      lineage: lineage(route_id: http_execution_route().route_id, event_id: "event-1"),
      payload: %{"phase" => "connected"}
    })
  end

  @spec execution_outcome() :: ExecutionOutcome.t()
  def execution_outcome do
    ExecutionOutcome.new!(%{
      route_id: execution_route().route_id,
      status: "succeeded",
      family: "http",
      raw_payload: %{"status" => 200},
      artifacts: [%{"artifact_ref" => "artifact://response"}],
      metrics: %{"latency_ms" => 42},
      failure: nil,
      lineage: lineage(route_id: execution_route().route_id)
    })
  end

  @spec execution_failure_outcome() :: ExecutionOutcome.t()
  def execution_failure_outcome do
    ExecutionOutcome.new!(%{
      route_id: execution_route().route_id,
      status: "failed",
      family: "process",
      raw_payload: %{"exit_status" => 1},
      artifacts: [],
      metrics: %{"latency_ms" => 155},
      failure: Failure.new!(%{failure_class: :launch_failed, reason: "spawn failed"}),
      lineage: lineage(route_id: execution_route().route_id)
    })
  end

  @spec lineage(keyword()) :: map()
  def lineage(overrides \\ []) do
    Enum.into(overrides, %{
      tenant_id: authority_decision().tenant_id,
      request_id: authority_decision().request_id,
      decision_id: authority_decision().decision_id,
      boundary_session_id: boundary_session_descriptor().boundary_session_id,
      attempt_ref: "attempt://1",
      route_id: "route-1",
      event_id: nil,
      idempotency_key: execution_intent_envelope().idempotency_key
    })
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
