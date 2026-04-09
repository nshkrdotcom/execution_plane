defmodule ExecutionPlane.Contracts.FailureClass do
  @moduledoc """
  Typed failure-class enum for the shared contract packet.
  """

  @definitions [
    policy_denied: %{
      primary_owner: :spine,
      retryable?: false,
      durable_truth_relevance: :durable_truth
    },
    route_unresolved: %{
      primary_owner: :spine,
      retryable?: true,
      durable_truth_relevance: :durable_truth
    },
    placement_unavailable: %{
      primary_owner: :execution_plane,
      retryable?: true,
      durable_truth_relevance: :durable_truth
    },
    launch_failed: %{
      primary_owner: :execution_plane,
      retryable?: true,
      durable_truth_relevance: :durable_truth
    },
    transport_failed: %{
      primary_owner: :execution_plane,
      retryable?: true,
      durable_truth_relevance: :durable_truth
    },
    protocol_framing_failed: %{
      primary_owner: :execution_plane,
      retryable?: false,
      durable_truth_relevance: :durable_truth
    },
    semantic_runtime_failed: %{
      primary_owner: :family_kit,
      retryable?: false,
      durable_truth_relevance: :durable_truth
    },
    approval_expired: %{
      primary_owner: :spine,
      retryable?: false,
      durable_truth_relevance: :durable_truth
    },
    lease_expired: %{
      primary_owner: :spine,
      retryable?: true,
      durable_truth_relevance: :durable_truth
    },
    attach_mismatch: %{
      primary_owner: :spine,
      retryable?: false,
      durable_truth_relevance: :durable_truth
    },
    remote_disconnect: %{
      primary_owner: :execution_plane,
      retryable?: true,
      durable_truth_relevance: :raw_fact_only
    },
    cancellation: %{
      primary_owner: :spine,
      retryable?: false,
      durable_truth_relevance: :durable_truth
    },
    timeout: %{
      primary_owner: :execution_plane,
      retryable?: true,
      durable_truth_relevance: :durable_truth
    }
  ]

  @type failure_class ::
          :policy_denied
          | :route_unresolved
          | :placement_unavailable
          | :launch_failed
          | :transport_failed
          | :protocol_framing_failed
          | :semantic_runtime_failed
          | :approval_expired
          | :lease_expired
          | :attach_mismatch
          | :remote_disconnect
          | :cancellation
          | :timeout

  @type metadata_t :: %{
          required(:primary_owner) => atom(),
          required(:retryable?) => boolean(),
          required(:durable_truth_relevance) => :durable_truth | :raw_fact_only
        }

  @spec values() :: [failure_class(), ...]
  def values, do: Keyword.keys(@definitions)

  @spec valid?(failure_class()) :: boolean()
  def valid?(failure_class), do: failure_class in values()

  @spec metadata(failure_class()) :: metadata_t()
  def metadata(failure_class) do
    case Keyword.fetch(@definitions, failure_class) do
      {:ok, metadata} -> metadata
      :error -> raise ArgumentError, "unknown failure_class: #{inspect(failure_class)}"
    end
  end

  @spec normalize!(failure_class() | String.t()) :: failure_class()
  def normalize!(failure_class) when is_atom(failure_class) do
    if valid?(failure_class) do
      failure_class
    else
      raise ArgumentError, "unknown failure_class: #{inspect(failure_class)}"
    end
  end

  def normalize!(failure_class) when is_binary(failure_class) do
    case Enum.find(values(), &(Atom.to_string(&1) == failure_class)) do
      nil -> raise ArgumentError, "unknown failure_class: #{inspect(failure_class)}"
      value -> value
    end
  end

  def normalize!(failure_class) do
    raise ArgumentError, "unknown failure_class: #{inspect(failure_class)}"
  end
end
