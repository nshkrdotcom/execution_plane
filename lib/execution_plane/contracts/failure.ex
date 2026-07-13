defmodule ExecutionPlane.Contracts.Failure do
  @moduledoc """
  Structured failure payload used by `ExecutionOutcome.v1`.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.FailureClass

  defstruct [
    :failure_class,
    :primary_owner,
    :retryable?,
    :durable_truth_relevance,
    :reason,
    details: %{}
  ]

  @type t :: %__MODULE__{
          failure_class: FailureClass.failure_class(),
          primary_owner: atom(),
          retryable?: boolean(),
          durable_truth_relevance: :durable_truth | :raw_fact_only,
          reason: String.t() | nil,
          details: map()
        }

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = failure), do: {:ok, failure}

  def new(attrs) do
    {:ok, build(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(map() | keyword() | t()) :: t()
  def new!(%__MODULE__{} = failure), do: failure

  def new!(attrs) do
    case new(attrs) do
      {:ok, failure} -> failure
      {:error, error} -> raise error
    end
  end

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = failure) do
    %{
      "failure_class" => failure.failure_class |> Atom.to_string(),
      "primary_owner" => failure.primary_owner |> Atom.to_string(),
      "retryable?" => failure.retryable?,
      "durable_truth_relevance" => failure.durable_truth_relevance |> Atom.to_string(),
      "reason" => failure.reason,
      "details" => Contracts.stringify_keys(failure.details)
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)
    failure_class = attrs |> Contracts.fetch_value(:failure_class) |> FailureClass.normalize!()
    metadata = FailureClass.metadata(failure_class)

    %__MODULE__{
      failure_class: failure_class,
      primary_owner: metadata.primary_owner,
      retryable?: metadata.retryable?,
      durable_truth_relevance: metadata.durable_truth_relevance,
      reason: Contracts.fetch_optional_stringish!(attrs, :reason),
      details: Contracts.fetch_optional_map!(attrs, :details, %{})
    }
  end
end
