defmodule ExecutionPlane.DiagnosticResult do
  @moduledoc """
  Structured result emitted by the diagnostic execution lane.
  """

  alias ExecutionPlane.Contracts

  @statuses %{"ok" => :ok, "error" => :error, "timeout" => :timeout}
  @attestations %{"weak_local" => :weak_local}

  @enforce_keys [:operation, :status, :payload, :execution_time_ms, :target_class, :attestation]
  defstruct [:operation, :status, :payload, :execution_time_ms, :target_class, :attestation]

  @type status :: :ok | :error | :timeout
  @type attestation :: :weak_local

  @type t :: %__MODULE__{
          operation: String.t(),
          status: status(),
          payload: map(),
          execution_time_ms: non_neg_integer(),
          target_class: String.t(),
          attestation: attestation()
        }

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Exception.t()}
  def new(%__MODULE__{} = result), do: {:ok, result}

  def new(attrs) do
    {:ok, new!(attrs)}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec new!(map() | keyword() | t()) :: t()
  def new!(%__MODULE__{} = result), do: result

  def new!(attrs) do
    attrs = Contracts.normalize_attrs(attrs)

    %__MODULE__{
      operation: Contracts.fetch_required_stringish!(attrs, :operation),
      status: normalize_status!(Contracts.fetch_required_stringish!(attrs, :status)),
      payload: Contracts.fetch_optional_map!(attrs, :payload, %{}),
      execution_time_ms: execution_time_ms!(attrs),
      target_class:
        Contracts.fetch_optional_stringish!(attrs, :target_class, "local-erlexec-weak"),
      attestation:
        normalize_attestation!(
          Contracts.fetch_optional_stringish!(attrs, :attestation, "weak_local")
        )
    }
  end

  @spec dump(t()) :: map()
  def dump(%__MODULE__{} = result) do
    %{
      "operation" => result.operation,
      "status" => Atom.to_string(result.status),
      "payload" => ExecutionPlane.Boundary.dump_value(result.payload),
      "execution_time_ms" => result.execution_time_ms,
      "target_class" => result.target_class,
      "attestation" => Atom.to_string(result.attestation)
    }
  end

  @spec with_elapsed(t(), non_neg_integer()) :: t()
  def with_elapsed(%__MODULE__{} = result, elapsed_ms)
      when is_integer(elapsed_ms) and elapsed_ms >= 0 do
    %{result | execution_time_ms: elapsed_ms}
  end

  @spec replace(t(), status(), map()) :: t()
  def replace(%__MODULE__{} = result, status, payload) when is_map(payload) do
    %{result | status: status, payload: payload}
  end

  defp execution_time_ms!(attrs) do
    case Contracts.fetch_value(attrs, :execution_time_ms) do
      value when is_integer(value) and value >= 0 ->
        value

      nil ->
        0

      other ->
        raise ArgumentError,
              "execution_time_ms must be a non-negative integer, got: #{inspect(other)}"
    end
  end

  defp normalize_status!(status) when is_binary(status) do
    case Map.fetch(@statuses, status) do
      {:ok, normalized} -> normalized
      :error -> raise ArgumentError, "unsupported diagnostic result status: #{inspect(status)}"
    end
  end

  defp normalize_attestation!(attestation) when is_binary(attestation) do
    case Map.fetch(@attestations, attestation) do
      {:ok, normalized} -> normalized
      :error -> raise ArgumentError, "unsupported diagnostic attestation: #{inspect(attestation)}"
    end
  end
end
