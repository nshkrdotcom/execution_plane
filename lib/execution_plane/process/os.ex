defmodule ExecutionPlane.Process.OS do
  @moduledoc false

  @kill_paths ["/bin/kill", "/usr/bin/kill"]
  @required_callbacks [privileged_user?: 0, await: 3, signal_process_group: 2]

  @type await_evidence :: %{
          required(:checks) => pos_integer(),
          required(:attempts_remaining) => non_neg_integer(),
          required(:delay_ms) => non_neg_integer()
        }

  @type signal_error :: :kill_command_not_found | {:kill_exit_status, pos_integer(), binary()}

  @callback privileged_user?() :: boolean()
  @callback await((-> boolean()), non_neg_integer(), non_neg_integer()) ::
              {:ok, await_evidence()} | {:error, await_evidence()}
  @callback signal_process_group(pos_integer(), binary()) :: :ok | {:error, signal_error()}

  @spec valid_boundary?(module()) :: boolean()
  def valid_boundary?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and
      Enum.all?(@required_callbacks, fn {name, arity} ->
        function_exported?(module, name, arity)
      end)
  end

  def valid_boundary?(_module), do: false

  @spec privileged_user?() :: boolean()
  def privileged_user? do
    case :os.type() do
      {:unix, _name} ->
        case System.cmd("id", ["-u"], stderr_to_stdout: true) do
          {"0\n", 0} -> true
          _other -> false
        end

      _other ->
        false
    end
  rescue
    _error -> false
  end

  @spec await((-> boolean()), non_neg_integer(), non_neg_integer()) ::
          {:ok, await_evidence()} | {:error, await_evidence()}
  def await(predicate, attempts, delay_ms)
      when is_function(predicate, 0) and is_integer(attempts) and attempts >= 0 and
             is_integer(delay_ms) and delay_ms >= 0 do
    do_await(predicate, attempts, delay_ms, 1)
  end

  @spec signal_process_group(pos_integer(), binary()) :: :ok | {:error, signal_error()}
  def signal_process_group(os_pid, signal)
      when is_integer(os_pid) and os_pid > 0 and is_binary(signal) and signal != "" do
    case kill_executable() do
      nil ->
        {:error, :kill_command_not_found}

      executable ->
        case System.cmd(executable, ["-#{signal}", "--", "-#{os_pid}"], stderr_to_stdout: true) do
          {_output, 0} -> :ok
          {output, status} -> {:error, {:kill_exit_status, status, String.trim_trailing(output)}}
        end
    end
  end

  defp do_await(predicate, attempts_remaining, delay_ms, checks) do
    evidence = %{checks: checks, attempts_remaining: attempts_remaining, delay_ms: delay_ms}

    if predicate.() do
      {:ok, evidence}
    else
      case attempts_remaining do
        0 ->
          {:error, evidence}

        _remaining ->
          Process.sleep(delay_ms)
          do_await(predicate, attempts_remaining - 1, delay_ms, checks + 1)
      end
    end
  end

  defp kill_executable do
    Enum.find(@kill_paths, &File.exists?/1)
  end
end
