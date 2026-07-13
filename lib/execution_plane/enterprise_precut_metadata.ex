defmodule ExecutionPlane.EnterprisePrecutMetadataSupport do
  @moduledoc false

  @spec build(module(), String.t(), [atom()], [atom()], map() | keyword()) ::
          {:ok, struct()} | {:error, term()}
  def build(module, contract_name, fields, required_fields, attrs) do
    with {:ok, attrs} <- normalize_attrs(attrs),
         [] <- missing_required_fields(attrs, required_fields) do
      {:ok, struct(module, attrs |> Map.take(fields) |> Map.put(:contract_name, contract_name))}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_attrs(attrs) when is_list(attrs), do: {:ok, Map.new(attrs)}

  defp normalize_attrs(attrs) when is_map(attrs) do
    if Map.has_key?(attrs, :__struct__), do: {:ok, Map.from_struct(attrs)}, else: {:ok, attrs}
  end

  defp normalize_attrs(_attrs), do: {:error, :invalid_attrs}

  defp missing_required_fields(attrs, required_fields) do
    Enum.reject(required_fields, &present?(Map.get(attrs, &1)))
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)
end

defmodule ExecutionPlane.ExecutionActivityMetadata do
  @moduledoc "Execution activity metadata consumed by Mezzanine activities."

  alias ExecutionPlane.EnterprisePrecutMetadataSupport

  @fields [
    :contract_name,
    :tenant_ref,
    :actor_ref,
    :resource_ref,
    :workflow_ref,
    :activity_call_ref,
    :lower_run_ref,
    :target_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :trace_id,
    :idempotency_key,
    :runtime_family,
    :timeout_policy,
    :heartbeat_policy
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutMetadataSupport.build(
        __MODULE__,
        "ExecutionPlane.ExecutionActivityMetadata.v1",
        @fields,
        [
          :tenant_ref,
          :actor_ref,
          :resource_ref,
          :workflow_ref,
          :activity_call_ref,
          :lower_run_ref,
          :target_ref,
          :authority_packet_ref,
          :permission_decision_ref,
          :trace_id,
          :idempotency_key,
          :runtime_family,
          :timeout_policy,
          :heartbeat_policy
        ],
        attrs
      )
end

defmodule ExecutionPlane.CancellationMetadata do
  @moduledoc "Cancellation metadata linked to authority, workflow, and lower run refs."

  alias ExecutionPlane.EnterprisePrecutMetadataSupport

  @fields [
    :contract_name,
    :cancellation_id,
    :tenant_ref,
    :actor_ref,
    :resource_ref,
    :workflow_ref,
    :activity_call_ref,
    :lower_run_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :trace_id,
    :idempotency_key
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutMetadataSupport.build(
        __MODULE__,
        "ExecutionPlane.CancellationMetadata.v1",
        @fields,
        [
          :cancellation_id,
          :tenant_ref,
          :actor_ref,
          :resource_ref,
          :workflow_ref,
          :lower_run_ref,
          :authority_packet_ref,
          :permission_decision_ref,
          :trace_id,
          :idempotency_key
        ],
        attrs
      )
end

defmodule ExecutionPlane.HeartbeatMetadata do
  @moduledoc "Heartbeat metadata linked to workflow activity and lease evidence."

  alias ExecutionPlane.EnterprisePrecutMetadataSupport

  @fields [
    :contract_name,
    :heartbeat_id,
    :tenant_ref,
    :resource_ref,
    :workflow_ref,
    :activity_call_ref,
    :lower_run_ref,
    :trace_id,
    :lease_ref
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutMetadataSupport.build(
        __MODULE__,
        "ExecutionPlane.HeartbeatMetadata.v1",
        @fields,
        [
          :heartbeat_id,
          :tenant_ref,
          :resource_ref,
          :workflow_ref,
          :activity_call_ref,
          :lower_run_ref,
          :trace_id,
          :lease_ref
        ],
        attrs
      )
end

defmodule ExecutionPlane.AttachGrantContract do
  @moduledoc "Lease-bound attach grant contract."

  alias ExecutionPlane.EnterprisePrecutMetadataSupport

  @fields [
    :contract_name,
    :attach_grant_id,
    :tenant_ref,
    :principal_ref,
    :resource_ref,
    :stream_ref,
    :lease_ref,
    :expires_at,
    :revocation_state,
    :authority_packet_ref,
    :permission_decision_ref,
    :trace_id
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutMetadataSupport.build(
        __MODULE__,
        "ExecutionPlane.AttachGrantLeaseBoundTraceable.v1",
        @fields,
        [
          :attach_grant_id,
          :tenant_ref,
          :principal_ref,
          :resource_ref,
          :stream_ref,
          :lease_ref,
          :expires_at,
          :revocation_state,
          :authority_packet_ref,
          :permission_decision_ref,
          :trace_id
        ],
        attrs
      )
end

defmodule ExecutionPlane.StreamLeaseContract do
  @moduledoc "Stream lease and revocation metadata contract."

  alias ExecutionPlane.EnterprisePrecutMetadataSupport

  @fields [
    :contract_name,
    :stream_ref,
    :tenant_ref,
    :resource_ref,
    :lease_ref,
    :epoch_ref,
    :trace_id,
    :revocation_state
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutMetadataSupport.build(
        __MODULE__,
        "ExecutionPlane.StreamLeaseContract.v1",
        @fields,
        [:stream_ref, :tenant_ref, :resource_ref, :lease_ref, :epoch_ref, :trace_id],
        attrs
      )
end

defmodule ExecutionPlane.RuntimeEvidenceRef do
  @moduledoc "Public-safe reference to raw runtime evidence."

  alias ExecutionPlane.EnterprisePrecutMetadataSupport

  @fields [
    :contract_name,
    :runtime_evidence_ref,
    :tenant_ref,
    :resource_ref,
    :lower_run_ref,
    :trace_id,
    :payload_hash,
    :redaction_posture
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutMetadataSupport.build(
        __MODULE__,
        "ExecutionPlane.RuntimeEvidenceRef.v1",
        @fields,
        [
          :runtime_evidence_ref,
          :tenant_ref,
          :resource_ref,
          :lower_run_ref,
          :trace_id,
          :payload_hash,
          :redaction_posture
        ],
        attrs
      )
end

defmodule ExecutionPlane.ActivitySideEffectIdempotency do
  @moduledoc """
  Activity-facing side-effect idempotency contract for Phase 4 durable workflows.

  Mezzanine owns workflow worker execution. Execution Plane owns the lower
  runtime side effect and dedupes retries by execution intent id and idempotency
  key.
  """

  alias ExecutionPlane.EnterprisePrecutMetadataSupport

  @contract_name "ExecutionPlane.ActivitySideEffectIdempotency.v1"
  @idempotency_scope "intent_id + idempotency_key"

  @fields [
    :contract_name,
    :tenant_ref,
    :actor_ref,
    :resource_ref,
    :workflow_ref,
    :activity_call_ref,
    :lower_run_ref,
    :intent_id,
    :idempotency_key,
    :authority_packet_ref,
    :permission_decision_ref,
    :trace_id,
    :lease_ref,
    :lease_evidence_ref,
    :heartbeat_policy,
    :timeout_policy,
    :retry_policy,
    :runtime_family,
    :side_effect_ref,
    :release_manifest_ref
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  @spec contract_name() :: String.t()
  def contract_name, do: @contract_name

  @spec idempotency_scope() :: String.t()
  def idempotency_scope, do: @idempotency_scope

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs),
    do:
      EnterprisePrecutMetadataSupport.build(
        __MODULE__,
        @contract_name,
        @fields,
        [
          :tenant_ref,
          :actor_ref,
          :resource_ref,
          :workflow_ref,
          :activity_call_ref,
          :lower_run_ref,
          :intent_id,
          :idempotency_key,
          :authority_packet_ref,
          :permission_decision_ref,
          :trace_id,
          :lease_ref,
          :lease_evidence_ref,
          :heartbeat_policy,
          :timeout_policy,
          :retry_policy,
          :runtime_family,
          :side_effect_ref,
          :release_manifest_ref
        ],
        attrs
      )

  @spec side_effect_key(t()) :: {String.t(), String.t()}
  def side_effect_key(%__MODULE__{} = activity),
    do: {activity.intent_id, activity.idempotency_key}

  @spec same_retry_scope?(t(), t()) :: boolean()
  def same_retry_scope?(%__MODULE__{} = left, %__MODULE__{} = right),
    do: side_effect_key(left) == side_effect_key(right)
end
