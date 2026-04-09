defmodule ExecutionPlane.Runtimes.Process.Exit do
  @moduledoc """
  Normalized process exit information for the lower runtime substrate.
  """

  defstruct status: :error, code: nil, signal: nil, reason: nil, stderr: nil

  @type t :: %__MODULE__{
          status: :success | :exit | :signal | :error,
          code: non_neg_integer() | nil,
          signal: atom() | integer() | nil,
          reason: term(),
          stderr: binary() | nil
        }

  @spec from_reason(term(), keyword()) :: t()
  def from_reason(reason, opts \\ []) do
    reason
    |> unwrap_shutdown()
    |> normalize_exit()
    |> put_stderr(Keyword.get(opts, :stderr))
  end

  @spec successful?(t()) :: boolean()
  def successful?(%__MODULE__{status: :success}), do: true
  def successful?(%__MODULE__{}), do: false

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = exit) do
    %{
      status: exit.status,
      code: exit.code,
      signal: exit.signal,
      reason: exit.reason,
      stderr: exit.stderr
    }
  end

  defp unwrap_shutdown({:shutdown, reason}), do: unwrap_shutdown(reason)
  defp unwrap_shutdown(reason), do: reason

  defp normalize_exit(:normal), do: %__MODULE__{status: :success, code: 0, reason: :normal}
  defp normalize_exit(0), do: %__MODULE__{status: :success, code: 0, reason: 0}

  defp normalize_exit(code) when is_integer(code) and code > 0,
    do: exit_with_code(code, normalize_code(code))

  defp normalize_exit({:exit_status, code}) when is_integer(code) and code >= 0 do
    exit_with_code({:exit_status, code}, normalize_code(code))
  end

  defp normalize_exit({:signal, signal}),
    do: %__MODULE__{status: :signal, signal: signal, reason: {:signal, signal}}

  defp normalize_exit({:signal, signal, _core}),
    do: %__MODULE__{status: :signal, signal: signal, reason: {:signal, signal}}

  defp normalize_exit(:enoent),
    do: %__MODULE__{status: :error, reason: {:command_not_found, :enoent}}

  defp normalize_exit(:eacces),
    do: %__MODULE__{status: :error, reason: {:command_not_found, :eacces}}

  defp normalize_exit(reason), do: %__MODULE__{status: :error, reason: reason}

  defp normalize_code(code) when code > 255 and rem(code, 256) == 0, do: div(code, 256)
  defp normalize_code(code), do: code

  defp exit_with_code(reason, 0), do: %__MODULE__{status: :success, code: 0, reason: reason}
  defp exit_with_code(reason, code), do: %__MODULE__{status: :exit, code: code, reason: reason}
  defp put_stderr(%__MODULE__{} = exit, nil), do: exit
  defp put_stderr(%__MODULE__{} = exit, stderr), do: %__MODULE__{exit | stderr: stderr}
end
