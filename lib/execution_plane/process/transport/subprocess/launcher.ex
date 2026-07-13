defmodule ExecutionPlane.Process.Transport.Subprocess.Launcher do
  @moduledoc false

  alias ExecutionPlane.Process.Transport.Error
  alias ExecutionPlane.Process.Transport.Options
  alias ExecutionPlane.Process.Transport.Subprocess.SignalControl

  @exec_wait_attempts 20
  @exec_wait_delay_ms 50

  @doc false
  def start(%Options{} = options) do
    with :ok <- preflight(options),
         exec_opts <-
           build_exec_opts(
             options.cwd,
             options.env,
             options.clear_env?,
             options.user,
             options.pty?
           ),
         argv <- normalize_command_argv(options.command, options.args),
         {:ok, pid, os_pid} <- exec_run(options.command, argv, exec_opts),
         :ok <- maybe_close_stdin_on_start(pid, options.close_stdin_on_start?) do
      {:ok, pid, os_pid}
    end
  end

  @doc false
  def preflight(%Options{} = options) do
    with :ok <- validate_cwd_exists(options.cwd),
         :ok <- validate_command_exists(options.command),
         :ok <- validate_user_switch_permitted(options.user, options.os) do
      ensure_erlexec_started(options.os)
    end
  end

  @doc false
  def validate_cwd_exists(nil), do: :ok

  def validate_cwd_exists(cwd) when is_binary(cwd) do
    if File.dir?(cwd) do
      :ok
    else
      {:error, Error.cwd_not_found(cwd)}
    end
  end

  @doc false
  def validate_command_exists(command) when is_binary(command) do
    cond do
      String.trim(command) == "" ->
        {:error, Error.command_not_found(command)}

      String.contains?(command, "/") ->
        if File.exists?(command), do: :ok, else: {:error, Error.command_not_found(command)}

      is_nil(System.find_executable(command)) ->
        {:error, Error.command_not_found(command)}

      true ->
        :ok
    end
  end

  @doc false
  def ensure_erlexec_started(os) do
    with :ok <- ensure_erlexec_application_started(),
         :ok <- ensure_exec_worker(os) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      {:error, reason} -> {:error, Error.startup_failed(reason)}
    end
  end

  @doc false
  def build_exec_opts(cwd, env, clear_env?, user, pty?) do
    []
    |> maybe_put_cwd(cwd)
    |> maybe_put_env(env, clear_env?)
    |> maybe_put_user(user)
    |> maybe_put_pty(pty?)
    |> maybe_put_process_group(pty?)
    # Group signaling is managed explicitly by the core so child exit does not
    # tear down erlexec's shared worker via :kill_group.
    |> Kernel.++([:stdin, :stdout, :stderr, :monitor])
  end

  @doc false
  def normalize_command_argv(command, args) when is_binary(command) and is_list(args) do
    [command | args] |> Enum.map(&to_charlist/1)
  end

  @doc false
  def exec_run(command, argv, exec_opts) do
    case :exec.run(argv, exec_opts) do
      {:ok, pid, os_pid} ->
        {:ok, pid, os_pid}

      {:error, reason} when reason in [:enoent, :eacces] ->
        {:error, Error.command_not_found(command, reason)}

      {:error, reason} ->
        {:error, Error.startup_failed(reason)}
    end
  end

  defp validate_user_switch_permitted(nil, _os), do: :ok

  defp validate_user_switch_permitted(user, os) do
    if os.privileged_user?() do
      :ok
    else
      {:error, Error.startup_failed({:user_switch_requires_privilege, user})}
    end
  end

  defp maybe_close_stdin_on_start(_pid, false), do: :ok
  defp maybe_close_stdin_on_start(pid, true), do: SignalControl.send_eof(pid)

  defp ensure_erlexec_application_started do
    case Application.ensure_all_started(:erlexec) do
      {:ok, _started_apps} -> :ok
      {:error, {:already_started, _app}} -> :ok
      {:error, {:erlexec, {:already_started, _app}}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_exec_worker(os) do
    case wait_for_exec_worker(os) do
      :ok -> :ok
      :error -> recover_missing_exec_worker(os)
    end
  end

  defp wait_for_exec_worker(os) do
    case os.await(&exec_worker_alive?/0, @exec_wait_attempts, @exec_wait_delay_ms) do
      {:ok, _evidence} -> :ok
      {:error, _evidence} -> :error
    end
  end

  defp recover_missing_exec_worker(os) do
    if exec_app_alive?() do
      {:error, :exec_not_running}
    else
      with :ok <- restart_erlexec_application(),
           :ok <- wait_for_exec_worker(os) do
        :ok
      else
        :error -> {:error, :exec_not_running}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp restart_erlexec_application do
    case Application.stop(:erlexec) do
      :ok -> ensure_erlexec_application_started()
      {:error, {:not_started, :erlexec}} -> ensure_erlexec_application_started()
      {:error, {:not_started, _app}} -> ensure_erlexec_application_started()
      {:error, reason} -> {:error, reason}
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

  defp maybe_put_cwd(opts, nil), do: opts
  defp maybe_put_cwd(opts, cwd), do: [{:cd, to_charlist(cwd)} | opts]

  defp maybe_put_env(opts, env, false) when map_size(env) == 0, do: opts

  defp maybe_put_env(opts, env, clear_env?) do
    env =
      env
      |> Enum.map(fn {key, value} -> {key, value} end)
      |> maybe_clear_env(clear_env?)

    [{:env, env} | opts]
  end

  defp maybe_clear_env(env, true), do: [:clear | env]
  defp maybe_clear_env(env, false), do: env

  defp maybe_put_user(opts, nil), do: opts
  defp maybe_put_user(opts, user), do: [{:user, to_charlist(user)} | opts]

  defp maybe_put_pty(opts, true), do: [:pty | opts]
  defp maybe_put_pty(opts, _pty?), do: opts

  # erlexec's PTY path already calls setsid(), which creates an isolated
  # session/process group. Adding {:group, 0} on top of that forces a redundant
  # setpgid(0, 0) that can fail with EPERM under load.
  defp maybe_put_process_group(opts, true), do: opts
  defp maybe_put_process_group(opts, false), do: [{:group, 0} | opts]
end
