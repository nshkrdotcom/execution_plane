defmodule ExecutionPlane.Contracts.ProcessExecutionIntent.V1 do
  @moduledoc """
  Process-family execution intent.

  `execution_surface`, `env_projection`, and `shutdown_policy` are frozen as
  Wave 1 carrier fields only. Detailed minimal-lane semantics remain
  provisional until Wave 3.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1, as: Envelope

  @contract_version Contracts.contract_version!(:process_execution_intent_v1)

  defstruct [
    :contract_version,
    :envelope,
    :command,
    :cwd,
    :stdio_mode,
    argv: [],
    env_projection: %{},
    execution_surface: %{},
    shutdown_policy: %{}
  ]

  @type t :: %__MODULE__{
          contract_version: String.t(),
          envelope: Envelope.t(),
          command: String.t(),
          argv: [String.t()],
          env_projection: map(),
          cwd: String.t() | nil,
          stdio_mode: String.t(),
          execution_surface: map(),
          shutdown_policy: map()
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
      "command" => intent.command,
      "argv" => intent.argv,
      "env_projection" => Contracts.stringify_keys(intent.env_projection),
      "cwd" => intent.cwd,
      "stdio_mode" => intent.stdio_mode,
      "execution_surface" => Contracts.stringify_keys(intent.execution_surface),
      "shutdown_policy" => Contracts.stringify_keys(intent.shutdown_policy)
    }
  end

  defp build(attrs) do
    attrs = Contracts.normalize_attrs(attrs)

    %__MODULE__{
      contract_version: Contracts.validate_contract_version!(attrs, @contract_version),
      envelope: attrs |> Contracts.fetch_value(:envelope) |> Envelope.new!(),
      command: Contracts.fetch_required_stringish!(attrs, :command),
      argv:
        Contracts.fetch_optional_list!(
          attrs,
          :argv,
          [],
          &Contracts.validate_non_empty_string!(&1, "argv")
        ),
      env_projection: Contracts.fetch_optional_map!(attrs, :env_projection, %{}),
      cwd: Contracts.fetch_optional_stringish!(attrs, :cwd),
      stdio_mode: Contracts.fetch_required_stringish!(attrs, :stdio_mode),
      execution_surface: Contracts.fetch_optional_map!(attrs, :execution_surface, %{}),
      shutdown_policy: Contracts.fetch_optional_map!(attrs, :shutdown_policy, %{})
    }
  end
end
