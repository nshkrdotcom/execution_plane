defmodule ExecutionPlane.Process do
  @moduledoc """
  Frozen Wave 3 helper surface for one-shot subprocess execution.

  This helper emits `ProcessExecutionIntent.v1`, resolves the minimal local
  process route, and executes through the kernel without requiring callers to
  hand-assemble contracts.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.ProcessExecutionIntent.V1, as: ProcessExecutionIntent
  alias ExecutionPlane.Kernel
  alias ExecutionPlane.Kernel.ExecutionResult
  alias ExecutionPlane.LaneSupport

  @spec run(map() | keyword(), keyword()) ::
          {:ok, ExecutionResult.t()} | {:error, ExecutionResult.t()}
  def run(invocation, opts \\ [])

  @spec run(String.t(), keyword()) :: {:ok, ExecutionResult.t()} | {:error, ExecutionResult.t()}
  def run(command, opts) when is_binary(command) and is_list(opts) do
    run(%{command: command}, opts)
  end

  def run(invocation, opts) do
    invocation = Contracts.normalize_attrs(invocation)
    timeout_ms = timeout_ms(invocation)
    lineage = LaneSupport.build_lineage("process", Keyword.get(opts, :lineage, %{}))

    intent =
      ProcessExecutionIntent.new!(%{
        envelope:
          LaneSupport.build_envelope(
            "process",
            "process",
            "process.run",
            lineage,
            Keyword.get(opts, :envelope, %{})
          ),
        command: Contracts.fetch_required_stringish!(invocation, :command),
        argv: Contracts.fetch_optional_list!(invocation, :argv, [], &to_string/1),
        env_projection: env_projection(invocation),
        cwd: Contracts.fetch_optional_stringish!(invocation, :cwd),
        stdin: Contracts.fetch_value(invocation, :stdin),
        clear_env: Contracts.fetch_optional_boolean!(invocation, :clear_env, false),
        user: Contracts.fetch_optional_stringish!(invocation, :user),
        stdio_mode: Contracts.fetch_optional_stringish!(invocation, :stdio_mode, "pipe"),
        stderr_mode: Contracts.fetch_optional_stringish!(invocation, :stderr_mode, "separate"),
        close_stdin: Contracts.fetch_optional_boolean!(invocation, :close_stdin, true),
        execution_surface: execution_surface(invocation),
        shutdown_policy: Contracts.fetch_optional_map!(invocation, :shutdown_policy, %{})
      })

    route =
      LaneSupport.build_route(
        "process",
        "process",
        "process",
        "local",
        %{"target_id" => Contracts.fetch_value(invocation, :target_id) || "local-runtime"},
        timeout_ms,
        lineage,
        Keyword.get(opts, :route, %{})
      )

    Kernel.execute(intent, route, LaneSupport.kernel_opts(opts))
  end

  defp timeout_ms(invocation) do
    case Contracts.fetch_value(invocation, :timeout_ms) do
      timeout when is_integer(timeout) and timeout > 0 -> timeout
      _other -> nil
    end
  end

  defp env_projection(invocation) do
    invocation
    |> Contracts.fetch_value(:env_projection)
    |> case do
      nil -> Contracts.fetch_optional_map!(invocation, :env, %{})
      value -> Contracts.ensure_map!(value, "env_projection")
    end
  end

  defp execution_surface(invocation) do
    case Contracts.fetch_value(invocation, :execution_surface) do
      nil ->
        %{
          "surface_kind" =>
            Contracts.fetch_optional_stringish!(invocation, :surface_kind, "local_subprocess")
        }

      surface ->
        Contracts.ensure_map!(surface, "execution_surface")
    end
  end
end
