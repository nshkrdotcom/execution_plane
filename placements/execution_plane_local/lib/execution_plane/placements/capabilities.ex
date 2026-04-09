defmodule ExecutionPlane.Placements.Capabilities do
  @moduledoc """
  Narrow placement-surface capabilities carried independently from command or
  provider semantics.
  """

  defstruct remote?: false,
            startup_kind: :spawn,
            path_semantics: :local,
            supports_run?: true,
            supports_streaming_stdio?: true,
            supports_pty?: true,
            supports_user?: true,
            supports_env?: true,
            supports_cwd?: true,
            interrupt_kind: :signal

  @type t :: %__MODULE__{
          remote?: boolean(),
          startup_kind: :spawn | :attach | :bridge,
          path_semantics: :local | :remote | :guest,
          supports_run?: boolean(),
          supports_streaming_stdio?: boolean(),
          supports_pty?: boolean(),
          supports_user?: boolean(),
          supports_env?: boolean(),
          supports_cwd?: boolean(),
          interrupt_kind: :signal | :stdin | :rpc | :none
        }

  @spec new(t() | map() | keyword()) :: {:ok, t()} | {:error, {:invalid_capabilities, term()}}
  def new(%__MODULE__{} = capabilities), do: {:ok, capabilities}

  def new(attrs) when is_list(attrs) do
    if Keyword.keyword?(attrs),
      do: new(Map.new(attrs)),
      else: {:error, {:invalid_capabilities, attrs}}
  end

  def new(attrs) when is_map(attrs) do
    attrs = Map.new(attrs)

    with {:ok, remote?} <- fetch_boolean(attrs, :remote?, false),
         {:ok, startup_kind} <-
           fetch_member(attrs, :startup_kind, [:spawn, :attach, :bridge], :spawn),
         {:ok, path_semantics} <-
           fetch_member(attrs, :path_semantics, [:local, :remote, :guest], :local),
         {:ok, supports_run?} <- fetch_boolean(attrs, :supports_run?, true),
         {:ok, supports_streaming_stdio?} <-
           fetch_boolean(attrs, :supports_streaming_stdio?, true),
         {:ok, supports_pty?} <- fetch_boolean(attrs, :supports_pty?, true),
         {:ok, supports_user?} <- fetch_boolean(attrs, :supports_user?, true),
         {:ok, supports_env?} <- fetch_boolean(attrs, :supports_env?, true),
         {:ok, supports_cwd?} <- fetch_boolean(attrs, :supports_cwd?, true),
         {:ok, interrupt_kind} <-
           fetch_member(attrs, :interrupt_kind, [:signal, :stdin, :rpc, :none], :signal) do
      {:ok,
       %__MODULE__{
         remote?: remote?,
         startup_kind: startup_kind,
         path_semantics: path_semantics,
         supports_run?: supports_run?,
         supports_streaming_stdio?: supports_streaming_stdio?,
         supports_pty?: supports_pty?,
         supports_user?: supports_user?,
         supports_env?: supports_env?,
         supports_cwd?: supports_cwd?,
         interrupt_kind: interrupt_kind
       }}
    end
  end

  def new(other), do: {:error, {:invalid_capabilities, other}}

  @spec new!(t() | map() | keyword()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, capabilities} ->
        capabilities

      {:error, reason} ->
        raise ArgumentError, "invalid placement capabilities: #{inspect(reason)}"
    end
  end

  defp fetch_boolean(attrs, key, default) do
    case Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default)) do
      value when is_boolean(value) -> {:ok, value}
      other -> {:error, {:invalid_capabilities, {key, other}}}
    end
  end

  defp fetch_member(attrs, key, allowed, default) do
    value = Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))

    cond do
      value in allowed -> {:ok, value}
      is_binary(value) and normalize_atomish(value) in allowed -> {:ok, normalize_atomish(value)}
      true -> {:error, {:invalid_capabilities, {key, value}}}
    end
  end

  defp normalize_atomish(value) when is_atom(value), do: value

  defp normalize_atomish(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> nil
  end
end
