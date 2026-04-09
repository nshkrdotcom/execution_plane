defmodule ExecutionPlane.Runtimes.Process do
  @moduledoc """
  Minimal process runtime for one-shot local execution in the execution-plane
  substrate.
  """

  alias ExecutionPlane.Contracts.Failure
  alias ExecutionPlane.Kernel.DispatchPlan
  alias ExecutionPlane.Placements.Surface
  alias ExecutionPlane.Runtimes.Process.{Exit, RunResult}

  @default_timeout_ms 30_000
  @exec_wait_attempts 20
  @exec_wait_delay_ms 50
  @run_stop_wait_ms 200
  @run_kill_wait_ms 500

  @spec family() :: String.t()
  def family, do: "process"

  @spec supports_intent?(struct() | map() | keyword()) :: boolean()
  def supports_intent?(%{__struct__: ExecutionPlane.Contracts.ProcessExecutionIntent.V1}),
    do: true

  def supports_intent?(_other), do: false

  @spec execute(DispatchPlan.t(), keyword()) :: {:ok, map()} | {:error, map()}
  def execute(
        %DispatchPlan{
          intent: %{__struct__: ExecutionPlane.Contracts.ProcessExecutionIntent.V1} = intent,
          placement_surface: surface
        } = plan,
        _opts
      ) do
    start_ms = System.monotonic_time(:millisecond)

    if supports_surface?(surface) do
      case run(
             command: intent.command,
             argv: intent.argv,
             cwd: intent.cwd,
             env: intent.env_projection,
             clear_env?: intent.clear_env,
             user: intent.user,
             stdin: intent.stdin,
             stderr: intent.stderr_mode |> normalize_stderr_mode(),
             close_stdin: intent.close_stdin,
             timeout: plan.timeout_ms,
             surface_kind: surface.surface_kind
           ) do
        {:ok, %RunResult{} = result} ->
          payload = run_result_payload(result)
          metrics = duration_metrics(start_ms)

          if Exit.successful?(result.exit) do
            {:ok, %{family: family(), raw_payload: payload, metrics: metrics, failure: nil}}
          else
            {:error, %{family: family(), raw_payload: payload, metrics: metrics, failure: nil}}
          end

        {:error, {:timeout, context}} ->
          {:error,
           %{
             family: family(),
             raw_payload: context,
             metrics: duration_metrics(start_ms),
             failure: Failure.new!(%{failure_class: :timeout, reason: "execution timed out"})
           }}

        {:error, {:unsupported_surface_kind, surface_kind}} ->
          {:error,
           %{
             family: family(),
             raw_payload: %{surface_kind: surface_kind},
             metrics: duration_metrics(start_ms),
             failure:
               Failure.new!(%{
                 failure_class: :placement_unavailable,
                 reason: "unsupported placement surface"
               })
           }}

        {:error, {:command_not_found, command}} ->
          {:error,
           %{
             family: family(),
             raw_payload: %{command: command},
             metrics: duration_metrics(start_ms),
             failure: Failure.new!(%{failure_class: :launch_failed, reason: "command not found"})
           }}

        {:error, {:cwd_not_found, cwd}} ->
          {:error,
           %{
             family: family(),
             raw_payload: %{cwd: cwd},
             metrics: duration_metrics(start_ms),
             failure: Failure.new!(%{failure_class: :launch_failed, reason: "cwd not found"})
           }}

        {:error, {:send_failed, reason}} ->
          {:error,
           %{
             family: family(),
             raw_payload: %{send_failed: reason},
             metrics: duration_metrics(start_ms),
             failure: Failure.new!(%{failure_class: :launch_failed, reason: "send failed"})
           }}

        {:error, reason} ->
          {:error,
           %{
             family: family(),
             raw_payload: %{error: inspect(reason)},
             metrics: duration_metrics(start_ms),
             failure:
               Failure.new!(%{failure_class: :launch_failed, reason: "process launch failed"})
           }}
      end
    else
      {:error,
       %{
         family: family(),
         raw_payload: %{surface_kind: surface && surface.surface_kind},
         metrics: duration_metrics(start_ms),
         failure:
           Failure.new!(%{
             failure_class: :placement_unavailable,
             reason: "Wave 2 only supports local_subprocess"
           })
       }}
    end
  end

  @spec run(keyword()) :: {:ok, RunResult.t()} | {:error, term()}
  def run(opts) when is_list(opts) do
    with {:ok, normalized} <- normalize_run_options(opts),
         :ok <- validate_surface(normalized.surface_kind),
         :ok <- validate_cwd_exists(normalized.cwd),
         :ok <- validate_command_exists(normalized.command),
         :ok <- ensure_erlexec_started(),
         exec_opts <-
           build_exec_opts(
             normalized.cwd,
             normalized.env,
             normalized.clear_env?,
             normalized.user
           ),
         argv <- normalize_command_argv(normalized.command, normalized.argv),
         {:ok, pid, os_pid} <- exec_run(normalized.command, argv, exec_opts) do
      run_started_exec(pid, os_pid, normalized)
    end
  end

  @spec supports_surface?(Surface.t() | nil) :: boolean()
  def supports_surface?(%Surface{surface_kind: "local_subprocess"}), do: true
  def supports_surface?(_surface), do: false

  defp normalize_run_options(opts) do
    normalized = %{
      command: Keyword.get(opts, :command),
      argv: Keyword.get(opts, :argv, []),
      cwd: Keyword.get(opts, :cwd),
      env: Keyword.get(opts, :env, %{}),
      clear_env?: Keyword.get(opts, :clear_env?, false),
      user: Keyword.get(opts, :user),
      stdin: Keyword.get(opts, :stdin),
      timeout: Keyword.get(opts, :timeout, @default_timeout_ms),
      stderr: Keyword.get(opts, :stderr, :separate),
      close_stdin: Keyword.get(opts, :close_stdin, true),
      surface_kind:
        Keyword.get(opts, :surface_kind, "local_subprocess")
        |> normalize_surface_kind()
    }

    with :ok <- validate_command(normalized.command),
         :ok <- validate_args(normalized.argv),
         :ok <- validate_env(normalized.env),
         :ok <- validate_timeout(normalized.timeout),
         :ok <- validate_stderr_mode(normalized.stderr),
         :ok <- validate_close_stdin(normalized.close_stdin),
         :ok <- validate_optional_user(normalized.user) do
      {:ok, normalized}
    end
  end

  defp validate_surface("local_subprocess"), do: :ok
  defp validate_surface(surface_kind), do: {:error, {:unsupported_surface_kind, surface_kind}}

  defp validate_command(command) when is_binary(command) do
    if String.trim(command) != "", do: :ok, else: {:error, {:invalid_command, command}}
  end

  defp validate_command(command), do: {:error, {:invalid_command, command}}

  defp validate_args(args) when is_list(args) do
    if Enum.all?(args, &is_binary/1), do: :ok, else: {:error, {:invalid_args, args}}
  end

  defp validate_args(args), do: {:error, {:invalid_args, args}}

  defp validate_env(env) when is_map(env), do: :ok
  defp validate_env(env), do: {:error, {:invalid_env, env}}

  defp validate_timeout(:infinity), do: :ok
  defp validate_timeout(timeout) when is_integer(timeout) and timeout >= 0, do: :ok
  defp validate_timeout(timeout), do: {:error, {:invalid_timeout, timeout}}

  defp validate_stderr_mode(mode) when mode in [:separate, :stdout], do: :ok
  defp validate_stderr_mode(mode), do: {:error, {:invalid_stderr, mode}}

  defp validate_close_stdin(value) when is_boolean(value), do: :ok
  defp validate_close_stdin(value), do: {:error, {:invalid_close_stdin, value}}

  defp validate_optional_user(nil), do: :ok
  defp validate_optional_user(user) when is_binary(user) and user != "", do: :ok
  defp validate_optional_user(user), do: {:error, {:invalid_user, user}}

  defp validate_cwd_exists(nil), do: :ok

  defp validate_cwd_exists(cwd) when is_binary(cwd) do
    if File.dir?(cwd), do: :ok, else: {:error, {:cwd_not_found, cwd}}
  end

  defp validate_command_exists(command) when is_binary(command) do
    cond do
      String.contains?(command, "/") ->
        if File.exists?(command), do: :ok, else: {:error, {:command_not_found, command}}

      is_nil(System.find_executable(command)) ->
        {:error, {:command_not_found, command}}

      true ->
        :ok
    end
  end

  defp ensure_erlexec_started do
    with :ok <- ensure_erlexec_application_started(),
         :ok <- ensure_exec_worker() do
      :ok
    end
  end

  defp ensure_erlexec_application_started do
    case Application.ensure_all_started(:erlexec) do
      {:ok, _started_apps} -> :ok
      {:error, {:already_started, _app}} -> :ok
      {:error, {:erlexec, {:already_started, _app}}} -> :ok
      {:error, reason} -> {:error, {:startup_failed, reason}}
    end
  end

  defp ensure_exec_worker do
    case wait_for_exec_worker(@exec_wait_attempts) do
      :ok -> :ok
      :error -> recover_missing_exec_worker()
    end
  end

  defp wait_for_exec_worker(0), do: if(exec_worker_alive?(), do: :ok, else: :error)

  defp wait_for_exec_worker(attempts_remaining) when attempts_remaining > 0 do
    if exec_worker_alive?() do
      :ok
    else
      Process.sleep(@exec_wait_delay_ms)
      wait_for_exec_worker(attempts_remaining - 1)
    end
  end

  defp recover_missing_exec_worker do
    if exec_app_alive?() do
      {:error, {:startup_failed, :exec_not_running}}
    else
      with :ok <- restart_erlexec_application(),
           :ok <- wait_for_exec_worker(@exec_wait_attempts) do
        :ok
      else
        :error -> {:error, {:startup_failed, :exec_not_running}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp restart_erlexec_application do
    case Application.stop(:erlexec) do
      :ok -> ensure_erlexec_application_started()
      {:error, {:not_started, _app}} -> ensure_erlexec_application_started()
      {:error, reason} -> {:error, {:startup_failed, reason}}
    end
  end

  defp exec_worker_alive? do
    case Process.whereis(:exec) do
      pid when is_pid(pid) -> Process.alive?(pid)
      _other -> false
    end
  end

  defp exec_app_alive? do
    case Process.whereis(:exec_app) do
      pid when is_pid(pid) -> Process.alive?(pid)
      _other -> false
    end
  end

  defp build_exec_opts(cwd, env, clear_env?, user) do
    []
    |> maybe_put_cwd(cwd)
    |> maybe_put_env(env, clear_env?)
    |> maybe_put_user(user)
    |> Kernel.++([{:group, 0}, :stdin, :stdout, :stderr, :monitor])
  end

  defp maybe_put_cwd(opts, nil), do: opts
  defp maybe_put_cwd(opts, cwd), do: [{:cd, to_charlist(cwd)} | opts]

  defp maybe_put_env(opts, env, false) when map_size(env) == 0, do: opts

  defp maybe_put_env(opts, env, clear_env?) do
    env =
      env
      |> Enum.map(fn {key, value} -> {to_string(key), to_string(value)} end)
      |> maybe_clear_env(clear_env?)

    [{:env, env} | opts]
  end

  defp maybe_clear_env(env, true), do: [:clear | env]
  defp maybe_clear_env(env, false), do: env
  defp maybe_put_user(opts, nil), do: opts
  defp maybe_put_user(opts, user), do: [{:user, to_charlist(user)} | opts]
  defp normalize_command_argv(command, args), do: [command | args] |> Enum.map(&to_charlist/1)

  defp exec_run(command, argv, exec_opts) do
    case :exec.run(argv, exec_opts) do
      {:ok, pid, os_pid} ->
        {:ok, pid, os_pid}

      {:error, reason} when reason in [:enoent, :eacces] ->
        {:error, {:command_not_found, command}}

      {:error, reason} ->
        {:error, {:startup_failed, reason}}
    end
  end

  defp run_started_exec(pid, os_pid, opts) do
    case maybe_send_run_input(pid, opts.stdin, opts.close_stdin) do
      :ok ->
        collect_run_output(pid, os_pid, opts, timeout_deadline(opts.timeout), [], [], [])

      {:error, reason} ->
        stop_run_exec_and_confirm_down(pid, os_pid)
        _ = flush_run_messages(pid, os_pid, opts.stderr, [], [], [])
        {:error, reason}
    end
  end

  defp maybe_send_run_input(pid, nil, true), do: send_run_eof(pid)
  defp maybe_send_run_input(_pid, nil, false), do: :ok

  defp maybe_send_run_input(pid, stdin, close_stdin) do
    with {:ok, payload} <- normalize_run_input(stdin),
         :ok <- send_run_payload(pid, payload) do
      if close_stdin, do: send_run_eof(pid), else: :ok
    end
  end

  defp normalize_run_input(stdin) do
    {:ok, normalize_payload(stdin)}
  rescue
    error -> {:error, {:send_failed, {:invalid_input, error}}}
  catch
    kind, reason -> {:error, {:send_failed, {kind, reason}}}
  end

  defp send_run_payload(pid, payload) do
    :exec.send(pid, payload)
    :ok
  catch
    kind, reason ->
      {:error, {:send_failed, {kind, reason}}}
  end

  defp send_run_eof(pid) do
    :exec.send(pid, :eof)
    :ok
  catch
    kind, reason ->
      {:error, {:send_failed, {kind, reason}}}
  end

  defp collect_run_output(pid, os_pid, opts, :infinity, stdout, stderr, output) do
    receive do
      {:stdout, ^os_pid, data} ->
        data = IO.iodata_to_binary(data)
        collect_run_output(pid, os_pid, opts, :infinity, [data | stdout], stderr, [data | output])

      {:stderr, ^os_pid, data} ->
        data = IO.iodata_to_binary(data)
        output = merge_stderr_output(data, output, opts.stderr)
        collect_run_output(pid, os_pid, opts, :infinity, stdout, [data | stderr], output)

      {:DOWN, ^os_pid, :process, ^pid, reason} ->
        build_run_result_after_down(pid, os_pid, reason, opts, stdout, stderr, output)
    end
  end

  defp collect_run_output(pid, os_pid, opts, deadline_ms, stdout, stderr, output) do
    case timeout_remaining(deadline_ms) do
      :expired ->
        handle_run_timeout(pid, os_pid, opts, stdout, stderr, output)

      remaining_timeout ->
        receive do
          {:stdout, ^os_pid, data} ->
            data = IO.iodata_to_binary(data)

            collect_run_output(pid, os_pid, opts, deadline_ms, [data | stdout], stderr, [
              data | output
            ])

          {:stderr, ^os_pid, data} ->
            data = IO.iodata_to_binary(data)
            output = merge_stderr_output(data, output, opts.stderr)
            collect_run_output(pid, os_pid, opts, deadline_ms, stdout, [data | stderr], output)

          {:DOWN, ^os_pid, :process, ^pid, reason} ->
            build_run_result_after_down(pid, os_pid, reason, opts, stdout, stderr, output)
        after
          remaining_timeout ->
            handle_run_timeout(pid, os_pid, opts, stdout, stderr, output)
        end
    end
  end

  defp build_run_result_after_down(pid, os_pid, reason, opts, stdout, stderr, output) do
    {stdout, stderr, output} =
      flush_run_messages(pid, os_pid, opts.stderr, stdout, stderr, output)

    exit = Exit.from_reason(reason, stderr: chunks_to_binary(stderr))

    {:ok,
     %RunResult{
       invocation: invocation(opts),
       stdout: chunks_to_binary(stdout),
       stderr: chunks_to_binary(stderr),
       output: chunks_to_binary(output),
       exit: exit,
       stderr_mode: opts.stderr
     }}
  end

  defp handle_run_timeout(pid, os_pid, opts, stdout, stderr, output) do
    stop_run_exec_and_confirm_down(pid, os_pid)

    {stdout, stderr, output} =
      flush_run_messages(pid, os_pid, opts.stderr, stdout, stderr, output)

    {:error,
     {:timeout,
      %{
        command: opts.command,
        argv: opts.argv,
        stdout: chunks_to_binary(stdout),
        stderr: chunks_to_binary(stderr),
        output: chunks_to_binary(output)
      }}}
  end

  defp merge_stderr_output(data, output, :stdout), do: [data | output]
  defp merge_stderr_output(_data, output, :separate), do: output

  defp chunks_to_binary(chunks) do
    chunks
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp flush_run_messages(pid, os_pid, stderr_mode, stdout, stderr, output) do
    receive do
      {:stdout, ^os_pid, data} ->
        data = IO.iodata_to_binary(data)
        flush_run_messages(pid, os_pid, stderr_mode, [data | stdout], stderr, [data | output])

      {:stderr, ^os_pid, data} ->
        data = IO.iodata_to_binary(data)
        output = merge_stderr_output(data, output, stderr_mode)
        flush_run_messages(pid, os_pid, stderr_mode, stdout, [data | stderr], output)

      {:DOWN, ^os_pid, :process, ^pid, _reason} ->
        flush_run_messages(pid, os_pid, stderr_mode, stdout, stderr, output)
    after
      0 -> {stdout, stderr, output}
    end
  end

  defp timeout_deadline(:infinity), do: :infinity
  defp timeout_deadline(timeout_ms), do: System.monotonic_time(:millisecond) + timeout_ms

  defp timeout_remaining(deadline_ms) do
    remaining = deadline_ms - System.monotonic_time(:millisecond)
    if remaining <= 0, do: :expired, else: remaining
  end

  defp stop_run_exec_and_confirm_down(pid, os_pid) do
    _ = kill_process_group(os_pid, "TERM")
    stop_exec(pid)

    case await_down(pid, os_pid, @run_stop_wait_ms) do
      :down ->
        :ok

      :timeout ->
        _ = kill_process_group(os_pid, "KILL")
        kill_exec(pid)
        _ = await_down(pid, os_pid, @run_kill_wait_ms)
        :ok
    end
  end

  defp await_down(pid, os_pid, timeout_ms) do
    receive do
      {:DOWN, ^os_pid, :process, ^pid, _reason} -> :down
    after
      timeout_ms -> :timeout
    end
  end

  defp stop_exec(pid) do
    :exec.stop(pid)
    :ok
  catch
    _, _ -> :ok
  end

  defp kill_exec(pid) do
    :exec.kill(pid, 9)
    :ok
  catch
    _, _ -> :ok
  end

  defp kill_process_group(os_pid, signal) when is_integer(os_pid) and os_pid > 0 do
    case System.find_executable("kill") do
      nil ->
        :ok

      executable ->
        _ = System.cmd(executable, ["-#{signal}", "--", "-#{os_pid}"], stderr_to_stdout: true)
    end
  end

  defp kill_process_group(_os_pid, _signal), do: :ok
  defp normalize_surface_kind(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_surface_kind(value) when is_binary(value), do: value

  defp normalize_stderr_mode(mode) when mode in [:separate, :stdout], do: mode
  defp normalize_stderr_mode("stdout"), do: :stdout
  defp normalize_stderr_mode(_mode), do: :separate

  defp duration_metrics(start_ms) do
    %{"duration_ms" => System.monotonic_time(:millisecond) - start_ms}
  end

  defp normalize_payload(message) when is_binary(message), do: message
  defp normalize_payload(message) when is_map(message), do: Jason.encode!(message)

  defp normalize_payload(message) when is_list(message) do
    IO.iodata_to_binary(message)
  rescue
    ArgumentError -> Jason.encode!(message)
  end

  defp normalize_payload(message), do: to_string(message)

  defp invocation(opts) do
    %{
      command: opts.command,
      argv: opts.argv,
      cwd: opts.cwd,
      env: opts.env,
      clear_env?: opts.clear_env?,
      user: opts.user
    }
  end

  defp run_result_payload(%RunResult{} = result) do
    %{
      invocation: result.invocation,
      stdout: result.stdout,
      stderr: result.stderr,
      output: result.output,
      exit: Exit.to_map(result.exit)
    }
  end
end
