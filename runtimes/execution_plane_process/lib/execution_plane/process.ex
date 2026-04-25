defmodule ExecutionPlane.Process do
  @moduledoc """
  Helper surface for one-shot subprocess execution.

  This helper emits `ProcessExecutionIntent.v1`, resolves the minimal local
  process route, and executes through the kernel without requiring callers to
  hand-assemble contracts.
  """

  alias ExecutionPlane.Admission.Rejection
  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.ProcessExecutionIntent.V1, as: ProcessExecutionIntent
  alias ExecutionPlane.ExecutionRequest
  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.Kernel
  alias ExecutionPlane.Kernel.ExecutionResult, as: KernelExecutionResult
  alias ExecutionPlane.Lane.Capabilities
  alias ExecutionPlane.LaneSupport

  @behaviour ExecutionPlane.Lane.Adapter

  @impl true
  def lane_id, do: :process

  @impl true
  def capabilities do
    Capabilities.new!(
      lane_id: "process",
      protocols: ["process"],
      surfaces: ["local_subprocess", "ssh_exec", "guest_bridge"],
      supports_execute: true,
      supports_stream: false
    )
  end

  @impl true
  def validate(%ExecutionRequest{lane_id: "process"}), do: :ok

  def validate(_request) do
    {:error,
     Rejection.new(
       :invalid_lane_request,
       "process adapter only accepts lane_id=process"
     )}
  end

  @impl true
  def execute(%ExecutionRequest{} = request, opts) do
    request.payload
    |> run(opts)
    |> case do
      {:ok, result} ->
        {:ok, adapter_result(request, "succeeded", result, nil)}

      {:error, result} ->
        {:error, adapter_result(request, "failed", result, "process execution failed")}
    end
  end

  @impl true
  def stream(%ExecutionRequest{} = request, _opts) do
    {:error,
     Rejection.new(
       :stream_not_supported,
       "process adapter does not expose stream/2 for execution requests",
       %{lane_id: request.lane_id}
     )}
  end

  @spec run(map() | keyword(), keyword()) ::
          {:ok, KernelExecutionResult.t()} | {:error, KernelExecutionResult.t()}
  def run(invocation, opts \\ [])

  @spec run(String.t(), keyword()) ::
          {:ok, KernelExecutionResult.t()} | {:error, KernelExecutionResult.t()}
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

  defp adapter_result(%ExecutionRequest{} = request, status, result, error) do
    ExecutionResult.new!(
      execution_ref: request.execution_ref,
      status: status,
      output: %{
        "events" => Enum.map(result.events, &ExecutionPlane.Boundary.dump_value/1),
        "outcome" => ExecutionPlane.Boundary.dump_value(result.outcome)
      },
      error: error,
      provenance: request.provenance
    )
  end
end
