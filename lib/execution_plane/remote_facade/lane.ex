defmodule ExecutionPlane.RemoteFacade.Lane do
  @moduledoc """
  Execution Plane-owned lower lane facade for distributed StackLab profiles.

  Lower lane execution is bounded by Execution Plane contracts. The default
  facade supports the diagnostic lane for deterministic local proof and returns
  serializable receipt maps.
  """

  alias ExecutionPlane.{ExecutionRequest, Lanes}

  @owner_group {__MODULE__, :lane}

  @spec owner_group() :: {module(), :lane}
  def owner_group, do: @owner_group

  @spec execute_lane(map(), keyword()) :: {:ok, map()} | {:error, map()}
  def execute_lane(request, opts \\ []) when is_map(request) and is_list(opts) do
    case ExecutionRequest.new(request) do
      {:ok, %ExecutionRequest{} = execution_request} ->
        execute_request(execution_request, opts)

      {:error, reason} ->
        {:error, error(:invalid_envelope, %{"reason" => Exception.message(reason)})}
    end
  rescue
    error in ArgumentError ->
      {:error, error(:invalid_envelope, %{"reason" => Exception.message(error)})}
  end

  defp lane_module(%ExecutionRequest{lane_id: "diagnostic"}), do: Lanes.DiagnosticLane
  defp lane_module(%ExecutionRequest{lane_id: :diagnostic}), do: Lanes.DiagnosticLane
  defp lane_module(%ExecutionRequest{}), do: Lanes.DiagnosticLane

  defp execute_request(%ExecutionRequest{} = execution_request, opts) do
    case lane_module(execution_request).execute(execution_request, opts) do
      {:ok, result} -> {:ok, normalize_result(result)}
      {:error, result} -> {:error, normalize_result(result)}
    end
  end

  defp normalize_result(%_{} = result), do: result |> Map.from_struct() |> stringify_keys()

  defp stringify_keys(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), stringify_value(value)} end)
    |> Map.new()
  end

  defp stringify_value(%_{} = value), do: value |> Map.from_struct() |> stringify_keys()
  defp stringify_value(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify_value(value) when is_list(value), do: Enum.map(value, &stringify_value/1)
  defp stringify_value(value) when is_map(value), do: stringify_keys(value)
  defp stringify_value(value), do: value

  defp error(code, attrs) do
    Map.merge(
      %{
        "code" => Atom.to_string(code),
        "owner" => "execution_plane",
        "facade" => "lane"
      },
      attrs
    )
  end
end
