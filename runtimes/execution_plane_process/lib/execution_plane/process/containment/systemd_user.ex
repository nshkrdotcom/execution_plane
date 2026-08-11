defmodule ExecutionPlane.Process.Containment.SystemdUser do
  @moduledoc """
  Strict Linux process containment through transient systemd user services.

  The service is created with `KillMode=control-group`. `stop/2` does not
  report success until systemd says the unit is gone/inactive and the cgroup
  is unpopulated. This reaches descendants that escape ordinary process-group
  cancellation with `setsid(2)` or reparenting.

  Environment values are not placed in argv. `:inherit_env` accepts variable
  names and uses systemd-run's name-only `--setenv=NAME` form to copy each
  value from the caller.
  """

  alias ExecutionPlane.Process.Containment

  @unit_pattern ~r/\A[a-zA-Z0-9][a-zA-Z0-9_.@-]{0,127}\z/
  @default_stop_timeout_ms 30_000
  @poll_interval_ms 50

  @type status :: %{
          state: :active | :inactive | :failed | :unknown,
          active_state: String.t() | nil,
          sub_state: String.t() | nil,
          result: String.t() | nil,
          control_group: String.t() | nil,
          populated?: boolean() | nil
        }

  @spec available?(keyword()) :: boolean()
  def available?(opts \\ []) do
    case command(opts, "systemctl", ["--user", "show-environment"]) do
      {_output, 0} -> true
      _other -> false
    end
  end

  @spec start(String.t(), String.t(), [String.t()], keyword()) ::
          {:ok, Containment.t()} | {:error, term()}
  def start(unit, program, argv \\ [], opts \\ [])
      when is_binary(unit) and is_binary(program) and is_list(argv) and is_list(opts) do
    with :ok <- validate_unit(unit),
         :ok <- validate_program(program),
         :ok <- validate_argv(argv),
         true <- available?(opts) || {:error, :systemd_user_unavailable},
         {:ok, args} <- start_args(unit, program, argv, opts),
         {output, 0} <- command(opts, "systemd-run", args),
         {:ok, status} <- wait_for_started(unit, opts) do
      {:ok,
       %Containment{
         manager: __MODULE__,
         id: unit,
         control_group: status.control_group,
         metadata: %{launch_output: String.trim(output), strength: :strict}
       }}
    else
      {output, code} when is_integer(code) ->
        {:error, {:systemd_run_failed, code, String.trim(output)}}

      {:error, _reason} = error ->
        error

      false ->
        {:error, :systemd_user_unavailable}
    end
  end

  @spec status(Containment.t() | String.t(), keyword()) :: {:ok, status()} | {:error, term()}
  def status(handle_or_unit, opts \\ []) do
    unit = unit_id(handle_or_unit)

    case command(opts, "systemctl", [
           "--user",
           "show",
           unit,
           "--no-pager",
           "--property=LoadState,ActiveState,SubState,Result,ControlGroup"
         ]) do
      {output, 0} ->
        properties = parse_properties(output)

        if properties["LoadState"] == "not-found" do
          {:ok, inactive_status()}
        else
          control_group = blank_to_nil(properties["ControlGroup"])

          {:ok,
           %{
             state: normalize_state(properties["ActiveState"]),
             active_state: blank_to_nil(properties["ActiveState"]),
             sub_state: blank_to_nil(properties["SubState"]),
             result: blank_to_nil(properties["Result"]),
             control_group: control_group,
             populated?: populated?(control_group)
           }}
        end

      {_output, code} when code in [3, 4, 5] ->
        {:ok, inactive_status()}

      {output, code} ->
        {:error, {:systemctl_status_failed, code, String.trim(output)}}
    end
  end

  @spec stop(Containment.t() | String.t(), keyword()) :: :ok | {:error, term()}
  def stop(handle_or_unit, opts \\ []) do
    unit = unit_id(handle_or_unit)
    timeout_ms = Keyword.get(opts, :timeout_ms, @default_stop_timeout_ms)

    with :ok <- validate_timeout(timeout_ms),
         {output, code} <- command(opts, "systemctl", ["--user", "stop", unit]),
         true <-
           code in [0, 3, 4, 5] || {:error, {:systemctl_stop_failed, code, String.trim(output)}},
         :ok <- wait_for_empty(unit, timeout_ms, opts) do
      :ok
    else
      {:error, _reason} = error -> error
      false -> {:error, :systemctl_stop_failed}
    end
  end

  @spec empty?(Containment.t() | String.t(), keyword()) ::
          {:ok, boolean()} | {:error, {:systemctl_status_failed, integer(), String.t()}}
  def empty?(handle_or_unit, opts \\ []) do
    case status(handle_or_unit, opts) do
      {:ok, %{state: state, populated?: populated?}}
      when state in [:inactive, :failed] and populated? in [false, nil] ->
        {:ok, true}

      {:ok, %{populated?: false}} ->
        {:ok, true}

      {:ok, _status} ->
        {:ok, false}

      {:error, _reason} = error ->
        error
    end
  end

  defp start_args(unit, program, argv, opts) do
    with :ok <- validate_cwd(Keyword.get(opts, :cwd)),
         :ok <- validate_inherit_env(Keyword.get(opts, :inherit_env, [])) do
      args = [
        "--user",
        "--quiet",
        "--collect",
        "--unit=#{unit}",
        "--property=Type=exec",
        "--property=KillMode=control-group",
        "--property=TimeoutStopSec=#{stop_seconds(opts)}"
      ]

      args = maybe_add_cwd(args, Keyword.get(opts, :cwd))
      args = Enum.reduce(Keyword.get(opts, :inherit_env, []), args, &(&2 ++ ["--setenv=#{&1}"]))
      {:ok, args ++ ["--", program | argv]}
    end
  end

  defp wait_for_started(unit, opts) do
    deadline = System.monotonic_time(:millisecond) + Keyword.get(opts, :start_timeout_ms, 5_000)
    do_wait_for_started(unit, deadline, opts)
  end

  defp do_wait_for_started(unit, deadline, opts) do
    case status(unit, opts) do
      {:ok, %{state: :active} = status} ->
        {:ok, status}

      # `systemd-run` returning zero proves Type=exec reached execve. A short
      # command may complete and be collected before the first 50 ms poll; that
      # is successful containment, not a start timeout.
      {:ok, %{state: :inactive, result: result} = status} when result in [nil, "success"] ->
        {:ok, status}

      {:ok, %{state: :failed} = status} ->
        {:error, {:containment_start_failed, status}}

      {:ok, _status} ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(@poll_interval_ms)
          do_wait_for_started(unit, deadline, opts)
        else
          {:error, :containment_start_timeout}
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp wait_for_empty(unit, timeout_ms, opts) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_for_empty(unit, deadline, opts)
  end

  defp do_wait_for_empty(unit, deadline, opts) do
    case empty?(unit, opts) do
      {:ok, true} ->
        :ok

      {:ok, false} ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(@poll_interval_ms)
          do_wait_for_empty(unit, deadline, opts)
        else
          {:error, {:containment_not_empty, unit}}
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp command(opts, executable, argv) do
    runner = Keyword.get(opts, :command_runner, &System.cmd/3)
    runner.(executable, argv, stderr_to_stdout: true)
  rescue
    error -> {Exception.message(error), 127}
  end

  defp parse_properties(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, "=", parts: 2) do
        [key, value] -> Map.put(acc, key, value)
        _other -> acc
      end
    end)
  end

  defp populated?(nil), do: nil

  defp populated?(control_group) do
    path = Path.join("/sys/fs/cgroup", String.trim_leading(control_group, "/"))

    case File.read(Path.join(path, "cgroup.events")) do
      {:ok, events} -> String.contains?(events, "populated 1")
      {:error, :enoent} -> false
      {:error, _reason} -> nil
    end
  end

  defp inactive_status do
    %{
      state: :inactive,
      active_state: nil,
      sub_state: nil,
      result: nil,
      control_group: nil,
      populated?: false
    }
  end

  defp normalize_state("active"), do: :active
  defp normalize_state("activating"), do: :active
  defp normalize_state("failed"), do: :failed
  defp normalize_state("inactive"), do: :inactive
  defp normalize_state(_other), do: :unknown

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp unit_id(%Containment{manager: __MODULE__, id: unit}), do: unit
  defp unit_id(unit) when is_binary(unit), do: unit

  defp maybe_add_cwd(args, nil), do: args
  defp maybe_add_cwd(args, cwd), do: args ++ ["--working-directory=#{cwd}"]

  defp stop_seconds(opts) do
    opts |> Keyword.get(:stop_timeout_ms, @default_stop_timeout_ms) |> div(1_000) |> max(1)
  end

  defp validate_unit(unit) do
    if Regex.match?(@unit_pattern, unit), do: :ok, else: {:error, {:invalid_unit, unit}}
  end

  defp validate_program(program) do
    if program != "" and not String.contains?(program, <<0>>),
      do: :ok,
      else: {:error, {:invalid_program, program}}
  end

  defp validate_argv(argv) do
    if Enum.all?(argv, &(is_binary(&1) and not String.contains?(&1, <<0>>))),
      do: :ok,
      else: {:error, {:invalid_argv, argv}}
  end

  defp validate_cwd(nil), do: :ok

  defp validate_cwd(cwd) when is_binary(cwd) do
    if Path.type(cwd) == :absolute and File.dir?(cwd),
      do: :ok,
      else: {:error, {:invalid_cwd, cwd}}
  end

  defp validate_cwd(cwd), do: {:error, {:invalid_cwd, cwd}}

  defp validate_inherit_env(names) when is_list(names) do
    if Enum.all?(names, &valid_env_name?/1),
      do: :ok,
      else: {:error, {:invalid_inherit_env, names}}
  end

  defp validate_inherit_env(names), do: {:error, {:invalid_inherit_env, names}}

  defp valid_env_name?(name) when is_binary(name), do: name =~ ~r/\A[A-Za-z_][A-Za-z0-9_]*\z/
  defp valid_env_name?(_name), do: false

  defp validate_timeout(timeout) when is_integer(timeout) and timeout > 0, do: :ok
  defp validate_timeout(timeout), do: {:error, {:invalid_timeout, timeout}}
end
