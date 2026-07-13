defmodule ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1 do
  @moduledoc """
  JSON-RPC-family execution intent.

  The lower transport binding and session-policy internals are Wave 1 carrier
  fields only and remain provisional until Wave 3.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1, as: Envelope

  @contract_version Contracts.contract_version!(:jsonrpc_execution_intent_v1)

  defstruct [
    :contract_version,
    :envelope,
    transport_binding: %{},
    protocol_schema: %{},
    request: %{},
    session_policy: %{}
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          envelope: Envelope.t(),
          transport_binding: map(),
          protocol_schema: map(),
          request: map(),
          session_policy: map()
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
  def dump(%__MODULE__{} = intent) do
    %{
      "contract_version" => intent.contract_version,
      "envelope" => Envelope.dump(intent.envelope),
      "transport_binding" => Contracts.stringify_keys(intent.transport_binding),
      "protocol_schema" => Contracts.stringify_keys(intent.protocol_schema),
      "request" => Contracts.stringify_keys(intent.request),
      "session_policy" => Contracts.stringify_keys(intent.session_policy)
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      envelope: attrs |> Contracts.fetch_value(:envelope) |> Envelope.new!(),
      transport_binding: Contracts.fetch_optional_map!(attrs, :transport_binding, %{}),
      protocol_schema: Contracts.fetch_optional_map!(attrs, :protocol_schema, %{}),
      request: Contracts.fetch_optional_map!(attrs, :request, %{}),
      session_policy: Contracts.fetch_optional_map!(attrs, :session_policy, %{})
    }
  end
end
