defmodule ExecutionPlane.Placements.Surface do
  @moduledoc """
  Narrow execution-surface contract for process placement and runtime routing.
  """

  alias ExecutionPlane.Placements.Capabilities

  @contract_version "execution_surface.v1"
  @default_surface_kind "local_subprocess"
  @surface_capabilities %{
    "local_subprocess" =>
      Capabilities.new!(
        remote?: false,
        startup_kind: :spawn,
        path_semantics: :local,
        supports_run?: true,
        supports_streaming_stdio?: true,
        supports_pty?: true,
        supports_user?: true,
        supports_env?: true,
        supports_cwd?: true,
        interrupt_kind: :signal
      ),
    "ssh_exec" =>
      Capabilities.new!(
        remote?: true,
        startup_kind: :spawn,
        path_semantics: :remote,
        supports_run?: true,
        supports_streaming_stdio?: true,
        supports_pty?: true,
        supports_user?: true,
        supports_env?: true,
        supports_cwd?: true,
        interrupt_kind: :signal
      ),
    "guest_bridge" =>
      Capabilities.new!(
        remote?: true,
        startup_kind: :bridge,
        path_semantics: :guest,
        supports_run?: true,
        supports_streaming_stdio?: true,
        supports_pty?: false,
        supports_user?: false,
        supports_env?: false,
        supports_cwd?: false,
        interrupt_kind: :rpc
      )
  }
  @forbidden_transport_option_keys ~w(command args cwd env clear_env? user)

  defstruct contract_version: @contract_version,
            surface_kind: @default_surface_kind,
            transport_options: %{},
            target_id: nil,
            lease_ref: nil,
            surface_ref: nil,
            boundary_class: nil,
            observability: %{}

  @type t :: %__MODULE__{
          contract_version: String.t(),
          surface_kind: String.t(),
          transport_options: map(),
          target_id: String.t() | nil,
          lease_ref: String.t() | nil,
          surface_ref: String.t() | nil,
          boundary_class: String.t() | atom() | nil,
          observability: map()
        }

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec supported_surface_kinds() :: [String.t(), ...]
  def supported_surface_kinds, do: @surface_capabilities |> Map.keys() |> Enum.sort()

  @spec placement_family(String.t() | atom() | map() | keyword() | t() | nil) :: String.t() | nil
  def placement_family(surface) do
    case normalize_surface_kind(surface_kind(surface)) do
      {:ok, "local_subprocess"} -> "local"
      {:ok, "ssh_exec"} -> "ssh"
      {:ok, "guest_bridge"} -> "guest"
      {:error, _reason} -> nil
    end
  end

  @spec capabilities(String.t() | atom() | map() | keyword() | t() | nil) ::
          {:ok, Capabilities.t()} | {:error, term()}
  def capabilities(surface) do
    with {:ok, surface_kind} <- normalize_surface_kind(surface_kind(surface)),
         {:ok, capabilities} <- Map.fetch(@surface_capabilities, surface_kind) do
      {:ok, capabilities}
    else
      :error -> {:error, {:unsupported_surface_kind, surface_kind(surface)}}
      {:error, _reason} = error -> error
    end
  end

  @spec path_semantics(String.t() | atom() | map() | keyword() | t() | nil) ::
          :local | :remote | :guest | nil
  def path_semantics(surface) do
    case capabilities(surface) do
      {:ok, %Capabilities{path_semantics: path_semantics}} -> path_semantics
      {:error, _reason} -> nil
    end
  end

  @spec remote_surface?(String.t() | atom() | map() | keyword() | t() | nil) :: boolean()
  def remote_surface?(surface) do
    case capabilities(surface) do
      {:ok, %Capabilities{remote?: remote?}} -> remote?
      {:error, _reason} -> false
    end
  end

  @spec nonlocal_path_surface?(String.t() | atom() | map() | keyword() | t() | nil) :: boolean()
  def nonlocal_path_surface?(surface), do: path_semantics(surface) in [:remote, :guest]

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = surface), do: {:ok, surface}

  def new(attrs) when is_list(attrs) do
    if Keyword.keyword?(attrs),
      do: new(Map.new(attrs)),
      else: {:error, {:invalid_execution_surface, attrs}}
  end

  def new(attrs) when is_map(attrs) do
    with :ok <-
           validate_contract_version(
             Map.get(attrs, :contract_version, Map.get(attrs, "contract_version"))
           ),
         {:ok, surface_kind} <-
           normalize_surface_kind(Map.get(attrs, :surface_kind, Map.get(attrs, "surface_kind"))),
         {:ok, transport_options} <-
           normalize_transport_options(
             Map.get(attrs, :transport_options, Map.get(attrs, "transport_options", %{}))
           ),
         :ok <-
           validate_optional_binary(
             Map.get(attrs, :target_id, Map.get(attrs, "target_id")),
             :target_id
           ),
         :ok <-
           validate_optional_binary(
             Map.get(attrs, :lease_ref, Map.get(attrs, "lease_ref")),
             :lease_ref
           ),
         :ok <-
           validate_optional_binary(
             Map.get(attrs, :surface_ref, Map.get(attrs, "surface_ref")),
             :surface_ref
           ),
         :ok <-
           validate_boundary_class(
             Map.get(attrs, :boundary_class, Map.get(attrs, "boundary_class"))
           ),
         :ok <-
           validate_observability(
             Map.get(attrs, :observability, Map.get(attrs, "observability", %{}))
           ) do
      {:ok,
       %__MODULE__{
         contract_version: @contract_version,
         surface_kind: surface_kind,
         transport_options: transport_options,
         target_id: Map.get(attrs, :target_id, Map.get(attrs, "target_id")),
         lease_ref: Map.get(attrs, :lease_ref, Map.get(attrs, "lease_ref")),
         surface_ref: Map.get(attrs, :surface_ref, Map.get(attrs, "surface_ref")),
         boundary_class: Map.get(attrs, :boundary_class, Map.get(attrs, "boundary_class")),
         observability: Map.get(attrs, :observability, Map.get(attrs, "observability", %{}))
       }}
    end
  end

  def new(other), do: {:error, {:invalid_execution_surface, other}}

  @spec new!(map() | keyword() | t()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, surface} -> surface
      {:error, reason} -> raise ArgumentError, "invalid execution surface: #{inspect(reason)}"
    end
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = surface) do
    %{
      "contract_version" => surface.contract_version,
      "surface_kind" => surface.surface_kind,
      "transport_options" => surface.transport_options,
      "target_id" => surface.target_id,
      "lease_ref" => surface.lease_ref,
      "surface_ref" => surface.surface_ref,
      "boundary_class" => surface.boundary_class,
      "observability" => surface.observability
    }
  end

  defp surface_kind(%__MODULE__{surface_kind: surface_kind}), do: surface_kind

  defp surface_kind(surface_kind) when is_atom(surface_kind) or is_binary(surface_kind),
    do: surface_kind

  defp surface_kind(attrs) when is_list(attrs), do: Keyword.get(attrs, :surface_kind)

  defp surface_kind(attrs) when is_map(attrs),
    do: Map.get(attrs, :surface_kind, Map.get(attrs, "surface_kind"))

  defp surface_kind(_other), do: nil

  defp validate_contract_version(nil), do: :ok
  defp validate_contract_version(@contract_version), do: :ok
  defp validate_contract_version(value), do: {:error, {:invalid_contract_version, value}}

  defp normalize_surface_kind(nil), do: {:ok, @default_surface_kind}

  defp normalize_surface_kind(value) when is_atom(value),
    do: normalize_surface_kind(Atom.to_string(value))

  defp normalize_surface_kind(value) when is_binary(value) do
    if Map.has_key?(@surface_capabilities, value) do
      {:ok, value}
    else
      {:error, {:invalid_surface_kind, value}}
    end
  end

  defp normalize_surface_kind(value), do: {:error, {:invalid_surface_kind, value}}

  defp normalize_transport_options(nil), do: {:ok, %{}}

  defp normalize_transport_options(options) when is_list(options) do
    if Keyword.keyword?(options) do
      options
      |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)
      |> normalize_transport_options()
    else
      {:error, {:invalid_transport_options, options}}
    end
  end

  defp normalize_transport_options(options) when is_map(options) do
    {:ok,
     options
     |> Enum.reject(fn {key, _value} -> to_string(key) in @forbidden_transport_option_keys end)
     |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)}
  end

  defp normalize_transport_options(options), do: {:error, {:invalid_transport_options, options}}

  defp validate_optional_binary(nil, _field), do: :ok
  defp validate_optional_binary(value, _field) when is_binary(value) and value != "", do: :ok
  defp validate_optional_binary(value, field), do: {:error, {:"invalid_#{field}", value}}

  defp validate_boundary_class(nil), do: :ok
  defp validate_boundary_class(value) when is_atom(value), do: :ok
  defp validate_boundary_class(value) when is_binary(value) and value != "", do: :ok
  defp validate_boundary_class(value), do: {:error, {:invalid_boundary_class, value}}

  defp validate_observability(value) when is_map(value), do: :ok
  defp validate_observability(value), do: {:error, {:invalid_observability, value}}
end
