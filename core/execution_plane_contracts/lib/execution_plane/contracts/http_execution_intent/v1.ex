defmodule ExecutionPlane.Contracts.HttpExecutionIntent.V1 do
  @moduledoc """
  HTTP-family execution intent.

  The payload fields below `envelope` are frozen as the minimal Wave 1 lane
  surface, but their detailed semantics stay provisional until Wave 3.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1, as: Envelope

  @contract_version Contracts.contract_version!(:http_execution_intent_v1)

  defstruct [
    :contract_version,
    :envelope,
    :request_shape,
    :stream_mode,
    :retry_class,
    headers: %{},
    body: %{},
    egress_surface: %{},
    timeouts: %{}
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          envelope: Envelope.t(),
          request_shape: String.t(),
          stream_mode: String.t(),
          headers: map(),
          body: map(),
          egress_surface: map(),
          timeouts: map(),
          retry_class: String.t() | nil
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
      "request_shape" => intent.request_shape,
      "stream_mode" => intent.stream_mode,
      "headers" => Contracts.stringify_keys(intent.headers),
      "body" => Contracts.stringify_keys(intent.body),
      "egress_surface" => Contracts.stringify_keys(intent.egress_surface),
      "timeouts" => Contracts.stringify_keys(intent.timeouts),
      "retry_class" => intent.retry_class
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      envelope: attrs |> Contracts.fetch_value(:envelope) |> Envelope.new!(),
      request_shape: Contracts.fetch_required_stringish!(attrs, :request_shape),
      stream_mode: Contracts.fetch_required_stringish!(attrs, :stream_mode),
      headers: Contracts.fetch_optional_map!(attrs, :headers, %{}),
      body: Contracts.fetch_optional_map!(attrs, :body, %{}),
      egress_surface: Contracts.fetch_optional_map!(attrs, :egress_surface, %{}),
      timeouts: Contracts.fetch_optional_map!(attrs, :timeouts, %{}),
      retry_class: Contracts.fetch_optional_stringish!(attrs, :retry_class)
    }
  end
end
