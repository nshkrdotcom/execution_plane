defmodule ExecutionPlane.Process.Transport.Subprocess.SignalControl do
  @moduledoc false

  alias ExecutionPlane.Process.Transport.Error

  @run_stop_wait_ms 200
  @run_kill_wait_ms 500

  @doc false
  def send_payload(pid, message, stdin_mode) when is_pid(pid) do
    payload =
      message
      |> normalize_payload()
      |> maybe_ensure_newline(stdin_mode)

    :exec.send(pid, payload)
    :ok
  catch
    kind, reason ->
      transport_error(Error.send_failed({kind, reason}))
  end

  @doc false
  def send_eof(pid) when is_pid(pid) do
    :exec.send(pid, :eof)
    :ok
  catch
    kind, reason ->
      transport_error(Error.send_failed({kind, reason}))
  end

  @doc false
  def end_input(pid, true), do: send_payload(pid, <<4>>, :raw)
  def end_input(pid, false), do: send_eof(pid)

  @doc false
  def interrupt(pid, _os_pid, {:stdin, payload}, _os)
      when is_pid(pid) and is_binary(payload) do
    :exec.send(pid, payload)
    :ok
  catch
    kind, reason ->
      transport_error(Error.send_failed({kind, reason}))
  end

  def interrupt(_pid, os_pid, :signal, os) when is_integer(os_pid) and os_pid > 0 do
    case os.signal_process_group(os_pid, "INT") do
      :ok ->
        :ok

      {:error, :kill_command_not_found} ->
        transport_error(Error.send_failed(:kill_command_not_found))

      {:error, {:kill_exit_status, status, output}} ->
        transport_error(Error.send_failed({:kill_exit_status, status, output}))
    end
  catch
    _, _ ->
      transport_error(Error.not_connected())
  end

  @doc false
  def force_stop({pid, os_pid}, os) when is_pid(pid) do
    stop_subprocess(pid, os_pid, os)
    :ok
  end

  def force_stop(_subprocess, _os), do: :ok

  @doc false
  def stop_run_and_confirm_down(pid, os_pid, os) do
    _ = kill_process_group(os_pid, "TERM", os)
    stop_exec(pid)

    case await_down(pid, os_pid, @run_stop_wait_ms) do
      :down ->
        :ok

      :timeout ->
        _ = kill_process_group(os_pid, "KILL", os)
        kill_exec(pid)
        _ = await_down(pid, os_pid, @run_kill_wait_ms)
        :ok
    end
  end

  @doc false
  def normalize_payload(message) when is_binary(message), do: message
  def normalize_payload(message) when is_map(message), do: Jason.encode!(message)

  def normalize_payload(message) when is_list(message) do
    IO.iodata_to_binary(message)
  rescue
    ArgumentError ->
      Jason.encode!(message)
  end

  def normalize_payload(message), do: to_string(message)

  defp maybe_ensure_newline(payload, :line) do
    if String.ends_with?(payload, "\n"), do: payload, else: payload <> "\n"
  end

  defp maybe_ensure_newline(payload, :raw), do: payload

  defp stop_subprocess(pid, os_pid, os) when is_pid(pid) do
    _ = kill_process_group(os_pid, "KILL", os)
    _ = :exec.kill(pid, 9)
    :ok
  catch
    _, _ -> :ok
  end

  defp kill_process_group(os_pid, signal, os) when is_integer(os_pid) and os_pid > 0 do
    _ = os.signal_process_group(os_pid, signal)
    :ok
  end

  defp kill_process_group(_os_pid, _signal, _os), do: :ok

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

  defp await_down(pid, os_pid, timeout_ms) do
    receive do
      {:DOWN, ^os_pid, :process, ^pid, _reason} -> :down
    after
      timeout_ms -> :timeout
    end
  end

  defp transport_error(%Error{} = error), do: {:error, {:transport, error}}
end
