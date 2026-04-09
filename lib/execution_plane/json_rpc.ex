defmodule ExecutionPlane.JsonRpc do
  @moduledoc """
  Frozen Wave 3 helper surface for unary JSON-RPC over the minimal process lane.

  This helper emits `JsonRpcExecutionIntent.v1`, resolves the local process
  target used for the request/response exchange, and executes through the
  kernel.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1, as: JsonRpcExecutionIntent
  alias ExecutionPlane.Kernel
  alias ExecutionPlane.Kernel.ExecutionResult
  alias ExecutionPlane.LaneSupport

  @spec call(map() | keyword(), keyword()) ::
          {:ok, ExecutionResult.t()} | {:error, ExecutionResult.t()}
  def call(binding, opts \\ []) do
    binding = Contracts.normalize_attrs(binding)
    timeout_ms = timeout_ms(binding)
    lineage = LaneSupport.build_lineage("process", Keyword.get(opts, :lineage, %{}))

    intent =
      JsonRpcExecutionIntent.new!(%{
        envelope:
          LaneSupport.build_envelope(
            "process",
            "jsonrpc",
            "jsonrpc.unary",
            lineage,
            Keyword.get(opts, :envelope, %{})
          ),
        transport_binding:
          Contracts.fetch_optional_map!(binding, :transport_binding, %{"mode" => "stdio"}),
        protocol_schema:
          Contracts.fetch_optional_map!(binding, :protocol_schema, %{"schema" => "jsonrpc-2.0"}),
        request: Contracts.fetch_optional_map!(binding, :request, %{}),
        session_policy: Contracts.fetch_optional_map!(binding, :session_policy, %{})
      })

    route =
      LaneSupport.build_route(
        "process",
        "jsonrpc",
        "process",
        "local",
        %{
          "command" => Contracts.fetch_required_stringish!(binding, :command),
          "argv" => Contracts.fetch_optional_list!(binding, :argv, [], &to_string/1),
          "cwd" => Contracts.fetch_optional_stringish!(binding, :cwd),
          "env" => Contracts.fetch_optional_map!(binding, :env, %{}),
          "execution_surface" => execution_surface(binding)
        },
        timeout_ms,
        lineage,
        Keyword.get(opts, :route, %{})
      )

    Kernel.execute(intent, route, LaneSupport.kernel_opts(opts))
  end

  defp timeout_ms(binding) do
    case Contracts.fetch_value(binding, :timeout_ms) do
      timeout when is_integer(timeout) and timeout > 0 -> timeout
      _other -> nil
    end
  end

  defp execution_surface(binding) do
    case Contracts.fetch_value(binding, :execution_surface) do
      nil ->
        %{
          "surface_kind" =>
            Contracts.fetch_optional_stringish!(binding, :surface_kind, "local_subprocess")
        }

      surface ->
        Contracts.ensure_map!(surface, "execution_surface")
    end
  end
end
