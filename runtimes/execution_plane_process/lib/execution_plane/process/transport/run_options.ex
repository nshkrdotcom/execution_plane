defmodule ExecutionPlane.Process.Transport.RunOptions do
  @moduledoc """
  Validated options for synchronous non-PTY command execution.
  """

  alias ExecutionPlane.Command
  alias ExecutionPlane.Process.OS

  @default_timeout_ms 30_000
  @default_os OS

  @enforce_keys [:command]
  defstruct command: nil,
            stdin: nil,
            timeout: @default_timeout_ms,
            stderr: :separate,
            close_stdin: true,
            os: @default_os

  @type stderr_mode :: :separate | :stdout

  @type t :: %__MODULE__{
          command: Command.t(),
          stdin: term(),
          timeout: timeout(),
          stderr: stderr_mode(),
          close_stdin: boolean(),
          os: module()
        }

  @type validation_error ::
          {:invalid_command, term()}
          | {:invalid_args, term()}
          | {:invalid_cwd, term()}
          | {:invalid_env, term()}
          | {:invalid_clear_env, term()}
          | {:invalid_user, term()}
          | {:invalid_timeout, term()}
          | {:invalid_stderr, term()}
          | {:invalid_close_stdin, term()}
          | {:invalid_os, term()}

  @doc """
  Builds validated run options for the raw transport command lane.
  """
  @spec new(Command.t(), keyword()) ::
          {:ok, t()} | {:error, {:invalid_run_options, validation_error()}}
  def new(%Command{} = command, opts \\ []) when is_list(opts) do
    normalized = %{
      command: command,
      stdin: Keyword.get(opts, :stdin),
      timeout: Keyword.get(opts, :timeout, @default_timeout_ms),
      stderr: Keyword.get(opts, :stderr, :separate),
      close_stdin: Keyword.get(opts, :close_stdin, true),
      os: Keyword.get(opts, :os, @default_os)
    }

    with :ok <- Command.validate(command),
         :ok <- validate_timeout(normalized.timeout),
         :ok <- validate_stderr(normalized.stderr),
         :ok <- validate_close_stdin(normalized.close_stdin),
         :ok <- validate_os(normalized.os) do
      {:ok, struct!(__MODULE__, normalized)}
    else
      {:error, reason} -> {:error, {:invalid_run_options, reason}}
    end
  end

  @doc """
  Returns the default synchronous command timeout in milliseconds.
  """
  @spec default_timeout_ms() :: 30_000
  def default_timeout_ms, do: @default_timeout_ms

  defp validate_timeout(:infinity), do: :ok
  defp validate_timeout(timeout) when is_integer(timeout) and timeout >= 0, do: :ok
  defp validate_timeout(timeout), do: {:error, {:invalid_timeout, timeout}}

  defp validate_stderr(mode) when mode in [:separate, :stdout], do: :ok
  defp validate_stderr(mode), do: {:error, {:invalid_stderr, mode}}

  defp validate_close_stdin(value) when is_boolean(value), do: :ok
  defp validate_close_stdin(value), do: {:error, {:invalid_close_stdin, value}}

  defp validate_os(module) when is_atom(module) do
    if OS.valid_boundary?(module) do
      :ok
    else
      {:error, {:invalid_os, module}}
    end
  end

  defp validate_os(module), do: {:error, {:invalid_os, module}}
end
