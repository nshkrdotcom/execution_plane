defmodule ExecutionPlane.OperatorTerminal.Surface do
  @moduledoc """
  Narrow operator-terminal ingress contract.

  This surface family is for hosting operator-facing TUIs. It is distinct from
  workload execution surfaces such as `:local_subprocess` and `:ssh_exec`.
  """

  @contract_version "operator_terminal_surface.v1"
  @default_surface_kind :local_terminal
  @surface_kinds [:local_terminal, :ssh_terminal, :distributed_terminal]
  @reserved_keys [
    :contract_version,
    :surface_kind,
    :transport_options,
    :surface_ref,
    :boundary_class,
    :observability
  ]

  defstruct contract_version: @contract_version,
            surface_kind: @default_surface_kind,
            transport_options: [],
            surface_ref: nil,
            boundary_class: nil,
            observability: %{}

  @type surface_kind :: :local_terminal | :ssh_terminal | :distributed_terminal
  @type boundary_class :: atom() | String.t() | nil

  @type t :: %__MODULE__{
          contract_version: String.t(),
          surface_kind: surface_kind(),
          transport_options: keyword(),
          surface_ref: String.t() | nil,
          boundary_class: boundary_class(),
          observability: map()
        }

  @type validation_error ::
          {:invalid_contract_version, term()}
          | {:invalid_surface_kind, term()}
          | {:invalid_transport_options, term()}
          | {:invalid_surface_ref, term()}
          | {:invalid_boundary_class, term()}
          | {:invalid_observability, term()}

  @spec supported_surface_kinds() :: [surface_kind(), ...]
  def supported_surface_kinds, do: @surface_kinds

  @spec default_surface_kind() :: :local_terminal
  def default_surface_kind, do: @default_surface_kind

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec reserved_keys() :: [atom(), ...]
  def reserved_keys, do: @reserved_keys

  @spec remote_surface?(t() | surface_kind()) :: boolean()
  def remote_surface?(%__MODULE__{surface_kind: surface_kind}), do: remote_surface?(surface_kind)
  def remote_surface?(:local_terminal), do: false
  def remote_surface?(_other), do: true

  @spec new(nil | keyword() | map()) :: {:ok, t()} | {:error, validation_error()}
  def new(nil), do: {:ok, %__MODULE__{surface_kind: @default_surface_kind}}

  def new(opts) when is_list(opts) do
    with {:ok, attrs} <- surface_attrs(opts) do
      build_surface(attrs)
    end
  end

  def new(%{} = attrs), do: build_surface(Map.new(attrs))
  def new(other), do: {:error, {:invalid_transport_options, other}}

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = surface) do
    %{
      contract_version: surface.contract_version,
      surface_kind: surface.surface_kind,
      transport_options: Map.new(surface.transport_options),
      surface_ref: surface.surface_ref,
      boundary_class: surface.boundary_class,
      observability: surface.observability
    }
  end

  defp build_surface(attrs) when is_map(attrs) do
    with :ok <- validate_contract_version(fetch(attrs, :contract_version, @contract_version)),
         {:ok, surface_kind} <-
           normalize_surface_kind(fetch(attrs, :surface_kind, @default_surface_kind)),
         {:ok, transport_options} <-
           normalize_transport_options(fetch(attrs, :transport_options, [])),
         :ok <- validate_optional_binary(fetch(attrs, :surface_ref), :surface_ref),
         :ok <- validate_boundary_class(fetch(attrs, :boundary_class)),
         :ok <- validate_observability(fetch(attrs, :observability, %{})) do
      {:ok,
       %__MODULE__{
         contract_version: @contract_version,
         surface_kind: surface_kind,
         transport_options: transport_options,
         surface_ref: fetch(attrs, :surface_ref),
         boundary_class: fetch(attrs, :boundary_class),
         observability: fetch(attrs, :observability, %{})
       }}
    end
  end

  defp surface_attrs(opts) when is_list(opts) do
    case Keyword.get(opts, :operator_terminal_surface) do
      nil ->
        {:ok, Map.new(Keyword.take(opts, @reserved_keys))}

      nested when is_list(nested) ->
        {:ok, Map.new(nested)}

      %{} = nested ->
        {:ok, nested}

      other ->
        {:error, {:invalid_transport_options, other}}
    end
  end

  defp validate_contract_version(@contract_version), do: :ok
  defp validate_contract_version(other), do: {:error, {:invalid_contract_version, other}}

  defp normalize_surface_kind(surface_kind) when surface_kind in @surface_kinds,
    do: {:ok, surface_kind}

  defp normalize_surface_kind(surface_kind) when is_binary(surface_kind) do
    case surface_kind do
      "local_terminal" -> {:ok, :local_terminal}
      "ssh_terminal" -> {:ok, :ssh_terminal}
      "distributed_terminal" -> {:ok, :distributed_terminal}
      other -> {:error, {:invalid_surface_kind, other}}
    end
  end

  defp normalize_surface_kind(other), do: {:error, {:invalid_surface_kind, other}}

  defp normalize_transport_options(nil), do: {:ok, []}

  defp normalize_transport_options(options) when is_list(options) do
    if Keyword.keyword?(options) do
      {:ok, options}
    else
      {:error, {:invalid_transport_options, options}}
    end
  end

  defp normalize_transport_options(options) when is_map(options) do
    {:ok, Enum.into(options, [], fn {key, value} -> {normalize_key(key), value} end)}
  end

  defp normalize_transport_options(other), do: {:error, {:invalid_transport_options, other}}

  defp validate_optional_binary(nil, _field), do: :ok
  defp validate_optional_binary(value, _field) when is_binary(value), do: :ok
  defp validate_optional_binary(value, field), do: {:error, {:"invalid_#{field}", value}}

  defp validate_boundary_class(nil), do: :ok
  defp validate_boundary_class(value) when is_atom(value) or is_binary(value), do: :ok
  defp validate_boundary_class(value), do: {:error, {:invalid_boundary_class, value}}

  defp validate_observability(value) when is_map(value), do: :ok
  defp validate_observability(value), do: {:error, {:invalid_observability, value}}

  defp fetch(attrs, key, default \\ nil),
    do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))

  defp normalize_key(key) when is_atom(key), do: key
  defp normalize_key(key) when is_binary(key), do: String.to_atom(key)
end
