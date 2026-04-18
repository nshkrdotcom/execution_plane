defmodule ExecutionPlane.Kernel do
  @moduledoc """
  Minimal execution kernel for contract validation, dispatch, timeout
  coordination, and raw-fact emission.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.ExecutionEvent.V1, as: ExecutionEvent
  alias ExecutionPlane.Contracts.ExecutionOutcome.V1, as: ExecutionOutcome
  alias ExecutionPlane.Contracts.ExecutionRoute.V1, as: ExecutionRoute
  alias ExecutionPlane.Contracts.HttpExecutionIntent.V1, as: HttpExecutionIntent
  alias ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1, as: JsonRpcExecutionIntent
  alias ExecutionPlane.Contracts.ProcessExecutionIntent.V1, as: ProcessExecutionIntent
  alias ExecutionPlane.Kernel.DispatchPlan
  alias ExecutionPlane.Kernel.ExecutionResult
  alias ExecutionPlane.Placements.Surface
  alias ExecutionPlane.Protocols.{HTTP, JsonRpc}
  alias ExecutionPlane.Runtimes.Process

  @default_timeout_ms 30_000

  @spec build_dispatch(
          struct() | map() | keyword(),
          ExecutionRoute.t() | map() | keyword(),
          keyword()
        ) ::
          {:ok, DispatchPlan.t()} | {:error, Exception.t()}
  def build_dispatch(intent, route, opts \\ []) do
    route = ExecutionRoute.new!(route)
    protocol_module = protocol_module_for(route.protocol)

    if is_nil(protocol_module) do
      {:error,
       ArgumentError.exception("unsupported lower protocol in Wave 1: #{inspect(route.protocol)}")}
    else
      intent = normalize_intent!(route.protocol, intent)
      placement_surface = build_placement_surface(intent, route)
      timeout_ms = effective_timeout_ms(intent, route, opts)

      validate_dispatch!(intent, route, placement_surface)

      {:ok,
       %DispatchPlan{
         route_id: route.route_id,
         family: route.family,
         protocol: route.protocol,
         protocol_module: protocol_module,
         route: route,
         intent: intent,
         placement_surface: placement_surface,
         timeout_ms: timeout_ms
       }}
    end
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec execute(struct() | map() | keyword(), ExecutionRoute.t() | map() | keyword(), keyword()) ::
          {:ok, ExecutionResult.t()} | {:error, ExecutionResult.t()}
  def execute(intent, route, opts \\ []) do
    case build_dispatch(intent, route, opts) do
      {:ok, %DispatchPlan{} = plan} ->
        {events, emitter} = {[], Keyword.get(opts, :emit)}

        {started_at, events} =
          emit_event(plan, events, emitter, "dispatch.started", start_payload(plan), opts)

        dispatch_module = plan.protocol_module

        case apply(dispatch_module, :execute, [plan, opts]) do
          {:ok, execution} ->
            {finished_at, events} =
              emit_event(
                plan,
                events,
                emitter,
                "dispatch.completed",
                completion_payload(plan, execution),
                opts
              )

            outcome = build_outcome(plan, execution, started_at, finished_at, "succeeded")
            {:ok, %ExecutionResult{plan: plan, events: events, outcome: outcome}}

          {:error, execution} ->
            {finished_at, events} =
              emit_event(
                plan,
                events,
                emitter,
                "dispatch.failed",
                failure_payload(plan, execution),
                opts
              )

            outcome = build_outcome(plan, execution, started_at, finished_at, "failed")
            {:error, %ExecutionResult{plan: plan, events: events, outcome: outcome}}
        end

      {:error, error} ->
        raise error
    end
  end

  @spec build_dispatch!(
          struct() | map() | keyword(),
          ExecutionRoute.t() | map() | keyword(),
          keyword()
        ) ::
          DispatchPlan.t()
  def build_dispatch!(intent, route, opts \\ []) do
    case build_dispatch(intent, route, opts) do
      {:ok, plan} -> plan
      {:error, error} -> raise error
    end
  end

  @spec protocol_module_for(String.t()) :: module() | nil
  def protocol_module_for("http"), do: HTTP
  def protocol_module_for("jsonrpc"), do: JsonRpc
  def protocol_module_for("process"), do: Process
  def protocol_module_for(_protocol), do: nil

  defp normalize_intent!("http", intent), do: HttpExecutionIntent.new!(intent)
  defp normalize_intent!("jsonrpc", intent), do: JsonRpcExecutionIntent.new!(intent)
  defp normalize_intent!("process", intent), do: ProcessExecutionIntent.new!(intent)

  defp build_placement_surface(
         %{
           __struct__: ExecutionPlane.Contracts.ProcessExecutionIntent.V1,
           execution_surface: surface
         },
         _route
       ) do
    Surface.new!(surface)
  end

  defp build_placement_surface(
         %{__struct__: ExecutionPlane.Contracts.JsonRpcExecutionIntent.V1},
         route
       ) do
    route.resolved_target
    |> Contracts.fetch_value(:execution_surface)
    |> case do
      nil -> %{"surface_kind" => "local_subprocess"}
      surface -> surface
    end
    |> Surface.new!()
  end

  defp build_placement_surface(_intent, _route), do: nil

  defp validate_dispatch!(intent, route, nil) do
    validate_envelope!(intent, route)
  end

  defp validate_dispatch!(intent, route, %Surface{} = placement_surface) do
    validate_envelope!(intent, route)

    placement_family = Surface.placement_family(placement_surface)

    if placement_family == route.placement_family do
      :ok
    else
      raise ArgumentError,
            "route placement #{inspect(route.placement_family)} does not match surface #{inspect(placement_surface.surface_kind)}"
    end
  end

  defp validate_envelope!(%{envelope: envelope}, route) do
    if envelope.family != route.family do
      raise ArgumentError,
            "intent envelope family #{inspect(envelope.family)} does not match route family #{inspect(route.family)}"
    end

    if envelope.protocol != route.protocol do
      raise ArgumentError,
            "intent envelope protocol #{inspect(envelope.protocol)} does not match route protocol #{inspect(route.protocol)}"
    end

    if envelope.idempotency_key != route.lineage.idempotency_key do
      raise ArgumentError, "intent idempotency_key does not match route lineage"
    end

    case envelope.trace_id do
      nil ->
        :ok

      trace_id when trace_id == route.lineage.trace_id ->
        :ok

      other ->
        raise ArgumentError,
              "intent trace_id must match route lineage.trace_id, got: #{inspect(other)}"
    end

    :ok
  end

  defp effective_timeout_ms(intent, route, opts) do
    now = now(opts)

    [
      Keyword.get(opts, :timeout_ms),
      Contracts.fetch_value(route.resolved_budget, :timeout_ms),
      per_intent_timeout(intent),
      deadline_timeout(intent, now)
    ]
    |> Enum.filter(&is_integer(&1))
    |> Enum.reject(&(&1 <= 0))
    |> case do
      [] -> @default_timeout_ms
      values -> Enum.min(values)
    end
  end

  defp per_intent_timeout(%{
         __struct__: ExecutionPlane.Contracts.HttpExecutionIntent.V1,
         timeouts: timeouts
       }) do
    Contracts.fetch_value(timeouts, :request_timeout_ms)
  end

  defp per_intent_timeout(_intent), do: nil

  defp deadline_timeout(%{envelope: %{deadline_at: deadline_at}}, now) do
    with deadline when is_binary(deadline) <- deadline_at,
         {:ok, deadline_at, _offset} <- DateTime.from_iso8601(deadline) do
      DateTime.diff(deadline_at, now, :millisecond)
    else
      _other -> nil
    end
  end

  defp now(opts) do
    case Keyword.get(opts, :now) do
      fun when is_function(fun, 0) -> fun.()
      %DateTime{} = now -> now
      _other -> DateTime.utc_now()
    end
  end

  defp emit_event(plan, events, emitter, event_type, payload, opts) do
    event_id = "event-#{System.unique_integer([:positive])}"
    timestamp = timestamp(opts)
    event = build_event(plan, event_id, event_type, timestamp, payload)

    if is_function(emitter, 1), do: emitter.(event)

    {timestamp, events ++ [event]}
  end

  defp build_event(plan, event_id, event_type, timestamp, payload) do
    ExecutionEvent.new!(%{
      event_id: event_id,
      route_id: plan.route.route_id,
      event_type: event_type,
      timestamp: timestamp,
      lineage:
        plan.route.lineage
        |> Map.put(:event_id, event_id),
      payload: payload
    })
  end

  defp build_outcome(plan, execution, started_at, finished_at, status) do
    ExecutionOutcome.new!(%{
      route_id: plan.route.route_id,
      status: status,
      family: execution.family,
      raw_payload: execution.raw_payload,
      artifacts: [],
      metrics:
        execution.metrics
        |> Map.put_new("started_at", started_at)
        |> Map.put_new("finished_at", finished_at)
        |> Map.put_new("timeout_ms", plan.timeout_ms),
      failure: execution.failure,
      lineage: plan.route.lineage
    })
  end

  defp start_payload(plan) do
    %{
      "family" => plan.family,
      "protocol" => plan.protocol,
      "timeout_ms" => plan.timeout_ms,
      "placement_family" => plan.route.placement_family
    }
  end

  defp completion_payload(_plan, execution) do
    %{"family" => execution.family, "status" => "succeeded"}
  end

  defp failure_payload(_plan, execution) do
    %{
      "family" => execution.family,
      "status" => "failed",
      "failure_class" => execution.failure && Atom.to_string(execution.failure.failure_class)
    }
  end

  defp timestamp(opts) do
    opts
    |> now()
    |> DateTime.to_iso8601()
  end
end
