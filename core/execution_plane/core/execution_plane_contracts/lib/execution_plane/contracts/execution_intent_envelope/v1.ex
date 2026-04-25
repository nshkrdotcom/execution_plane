defmodule ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1 do
  @moduledoc """
  Spine-to-Execution neutral intent envelope.
  """

  alias ExecutionPlane.Contracts

  @contract_version Contracts.contract_version!(:execution_intent_envelope_v1)

  defstruct [
    :contract_version,
    :intent_id,
    :family,
    :protocol,
    :trace_id,
    :idempotency_key,
    :boundary_session_id,
    :decision_id,
    :lease_ref,
    :route_template_ref,
    :attempt_ref,
    :deadline_at,
    :cancellation_ref,
    credential_handle_refs: [],
    requested_capabilities: [],
    extensions: %{}
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          intent_id: String.t(),
          family: String.t(),
          protocol: String.t(),
          trace_id: String.t() | nil,
          idempotency_key: String.t(),
          boundary_session_id: String.t(),
          decision_id: String.t(),
          lease_ref: String.t() | nil,
          route_template_ref: String.t() | nil,
          credential_handle_refs: [String.t()],
          attempt_ref: String.t() | nil,
          deadline_at: String.t() | nil,
          cancellation_ref: String.t() | nil,
          requested_capabilities: [String.t()],
          extensions: map()
        }

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    {:ok, build(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(map() | keyword() | t()) :: t()
  def new!(%__MODULE__{} = value), do: value

  def new!(attrs) do
    case new(attrs) do
      {:ok, value} -> value
      {:error, error} -> raise error
    end
  end

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = envelope) do
    %{
      "contract_version" => envelope.contract_version,
      "intent_id" => envelope.intent_id,
      "family" => envelope.family,
      "protocol" => envelope.protocol,
      "trace_id" => envelope.trace_id,
      "idempotency_key" => envelope.idempotency_key,
      "boundary_session_id" => envelope.boundary_session_id,
      "decision_id" => envelope.decision_id,
      "lease_ref" => envelope.lease_ref,
      "route_template_ref" => envelope.route_template_ref,
      "credential_handle_refs" => envelope.credential_handle_refs,
      "attempt_ref" => envelope.attempt_ref,
      "deadline_at" => envelope.deadline_at,
      "cancellation_ref" => envelope.cancellation_ref,
      "requested_capabilities" => envelope.requested_capabilities,
      "extensions" => Contracts.stringify_keys(envelope.extensions)
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)
    deadline_at = Contracts.fetch_optional_stringish!(attrs, :deadline_at)

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      intent_id: Contracts.fetch_required_stringish!(attrs, :intent_id),
      family: Contracts.fetch_required_stringish!(attrs, :family),
      protocol: Contracts.fetch_required_stringish!(attrs, :protocol),
      trace_id: Contracts.fetch_optional_stringish!(attrs, :trace_id),
      idempotency_key: Contracts.fetch_required_stringish!(attrs, :idempotency_key),
      boundary_session_id: Contracts.fetch_required_stringish!(attrs, :boundary_session_id),
      decision_id: Contracts.fetch_required_stringish!(attrs, :decision_id),
      lease_ref: Contracts.fetch_optional_stringish!(attrs, :lease_ref),
      route_template_ref: Contracts.fetch_optional_stringish!(attrs, :route_template_ref),
      credential_handle_refs:
        Contracts.fetch_optional_list!(
          attrs,
          :credential_handle_refs,
          [],
          &Contracts.validate_opaque_handle_ref!(&1, "credential_handle_ref")
        ),
      attempt_ref: Contracts.fetch_optional_stringish!(attrs, :attempt_ref),
      deadline_at:
        if(is_nil(deadline_at),
          do: nil,
          else: Contracts.validate_iso8601!(deadline_at, "deadline_at")
        ),
      cancellation_ref: Contracts.fetch_optional_stringish!(attrs, :cancellation_ref),
      requested_capabilities:
        Contracts.fetch_optional_list!(
          attrs,
          :requested_capabilities,
          [],
          &Contracts.validate_non_empty_string!(&1, "requested_capability")
        ),
      extensions: Contracts.normalize_extensions!(attrs)
    }
  end
end
