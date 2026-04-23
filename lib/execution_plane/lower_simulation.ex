defmodule ExecutionPlane.LowerSimulation do
  @moduledoc """
  Route-configured lower-runtime simulation support.

  This module is deliberately lower-only: it consumes a resolved route target
  descriptor and emits normal lower-family raw payloads plus bounded evidence
  artifacts. Callers do not pass a public `simulation:` option.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.ExecutionOutcome.V1, as: ExecutionOutcome
  alias ExecutionPlane.Contracts.ExecutionRoute.V1, as: ExecutionRoute
  alias ExecutionPlane.Contracts.Failure
  alias ExecutionPlane.Contracts.LowerSimulationEvidence.V1, as: Evidence
  alias ExecutionPlane.Contracts.NoEgressPolicy.V1, as: NoEgressPolicy

  @scenario_key :lower_simulation
  @supported_statuses ["succeeded", "failed"]
  @supported_protocols ["http", "process"]
  @default_metrics %{"duration_ms" => 0}

  @type simulation_result :: :not_configured | {:ok, map()} | {:error, map()}

  @spec execute_if_configured(
          String.t(),
          struct(),
          ExecutionRoute.t(),
          integer()
        ) :: simulation_result()
  def execute_if_configured(protocol, intent, %ExecutionRoute{} = route, started_ms)
      when protocol in @supported_protocols and is_integer(started_ms) do
    case Contracts.fetch_value(route.resolved_target, @scenario_key) do
      nil ->
        :not_configured

      descriptor ->
        case normalize_descriptor(protocol, descriptor) do
          {:ok, descriptor} ->
            execute_descriptor(protocol, intent, route, descriptor, started_ms)

          {:error, reason} ->
            invalid_descriptor_result(route, reason, started_ms)
        end
    end
  end

  def execute_if_configured(_protocol, _intent, _route, _started_ms), do: :not_configured

  defp execute_descriptor(protocol, intent, route, descriptor, started_ms) do
    raw_payload = descriptor.raw_payload

    evidence =
      Evidence.new!(%{
        scenario_ref: descriptor.scenario_ref,
        route_id: route.route_id,
        family: route.family,
        protocol: route.protocol,
        side_effect_policy: descriptor.side_effect_policy,
        side_effect_result: "not_attempted",
        outcome_contract_version: ExecutionOutcome.contract_version(),
        outcome_status: descriptor.status,
        outcome_family: route.family,
        input_fingerprint: fingerprint(input_fact(protocol, intent)),
        output_fingerprint: fingerprint(raw_payload),
        raw_payload_shape: raw_payload_shape(raw_payload),
        lineage: route.lineage
      })

    execution = %{
      family: route.family,
      raw_payload: raw_payload,
      metrics:
        descriptor.metrics
        |> Map.put_new("duration_ms", System.monotonic_time(:millisecond) - started_ms),
      failure: descriptor.failure,
      artifacts: [evidence_artifact(route, evidence, descriptor.no_egress_policy)]
    }

    if descriptor.status == "succeeded", do: {:ok, execution}, else: {:error, execution}
  end

  defp invalid_descriptor_result(route, reason, started_ms) do
    {:error,
     %{
       family: route.family,
       raw_payload: %{
         error: inspect(reason),
         side_effect_result: "blocked_before_dispatch"
       },
       metrics:
         Map.put(
           @default_metrics,
           "duration_ms",
           System.monotonic_time(:millisecond) - started_ms
         ),
       failure:
         Failure.new!(%{
           failure_class: :route_unresolved,
           reason: "invalid lower simulation route"
         }),
       artifacts: []
     }}
  end

  defp normalize_descriptor(protocol, descriptor) when is_map(descriptor) do
    descriptor = Contracts.stringify_keys(descriptor)

    with {:ok, scenario_ref} <- required_string(descriptor, "scenario_ref"),
         {:ok, status} <- supported_status(descriptor),
         {:ok, raw_payload} <- required_raw_payload(descriptor),
         {:ok, metrics} <- optional_metrics(descriptor),
         {:ok, failure} <- optional_failure(descriptor, status),
         {:ok, no_egress_policy} <- no_egress_policy(descriptor),
         {:ok, side_effect_policy} <- side_effect_policy(protocol, descriptor) do
      {:ok,
       %{
         scenario_ref: scenario_ref,
         status: status,
         raw_payload: raw_payload,
         metrics: metrics,
         failure: failure,
         no_egress_policy: no_egress_policy,
         side_effect_policy: side_effect_policy
       }}
    end
  end

  defp normalize_descriptor(_protocol, descriptor),
    do: {:error, {:invalid_lower_simulation_descriptor, descriptor}}

  defp required_string(descriptor, key) do
    case Map.fetch(descriptor, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _other -> {:error, {:missing_required_lower_simulation_key, key}}
    end
  end

  defp supported_status(descriptor) do
    status = Map.get(descriptor, "status", "succeeded")

    if status in @supported_statuses do
      {:ok, status}
    else
      {:error, {:unsupported_lower_simulation_status, status}}
    end
  end

  defp required_raw_payload(descriptor) do
    case Map.fetch(descriptor, "raw_payload") do
      {:ok, payload} when is_map(payload) -> {:ok, payload}
      _other -> {:error, {:missing_required_lower_simulation_key, "raw_payload"}}
    end
  end

  defp optional_metrics(descriptor) do
    case Map.get(descriptor, "metrics", @default_metrics) do
      metrics when is_map(metrics) -> {:ok, metrics}
      other -> {:error, {:invalid_lower_simulation_metrics, other}}
    end
  end

  defp optional_failure(descriptor, "succeeded") do
    case Map.get(descriptor, "failure") do
      nil -> {:ok, nil}
      other -> {:error, {:successful_lower_simulation_cannot_have_failure, other}}
    end
  end

  defp optional_failure(descriptor, "failed") do
    failure =
      descriptor
      |> Map.get("failure", %{
        "failure_class" => "transport_failed",
        "reason" => "simulated failure"
      })
      |> Failure.new!()

    {:ok, failure}
  rescue
    error in ArgumentError -> {:error, {:invalid_lower_simulation_failure, error.message}}
  end

  defp no_egress_policy(descriptor) do
    descriptor
    |> Map.fetch("no_egress_policy")
    |> case do
      {:ok, policy} -> {:ok, NoEgressPolicy.new!(policy)}
      :error -> {:error, {:missing_required_lower_simulation_key, "no_egress_policy"}}
    end
  rescue
    error in ArgumentError -> {:error, {:invalid_no_egress_policy, error.message}}
  end

  defp side_effect_policy("http", descriptor) do
    validate_side_effect_policy(descriptor, "deny_external_egress")
  end

  defp side_effect_policy("process", descriptor) do
    validate_side_effect_policy(descriptor, "deny_process_spawn")
  end

  defp validate_side_effect_policy(descriptor, expected) do
    case Map.get(descriptor, "side_effect_policy", expected) do
      ^expected -> {:ok, expected}
      other -> {:error, {:invalid_lower_simulation_side_effect_policy, other, expected}}
    end
  end

  defp input_fact("http", intent) do
    %{
      family: "http",
      request_shape: intent.request_shape,
      stream_mode: intent.stream_mode,
      headers: intent.headers,
      body: intent.body
    }
  end

  defp input_fact("process", intent) do
    %{
      family: "process",
      command: intent.command,
      argv: intent.argv,
      env_projection: intent.env_projection,
      cwd: intent.cwd,
      stdin: intent.stdin
    }
  end

  defp fingerprint(value) do
    bytes = :erlang.term_to_binary(Contracts.stringify_keys(value))

    %{
      "sha256" => "sha256:" <> Base.encode16(:crypto.hash(:sha256, bytes), case: :lower),
      "byte_size" => byte_size(bytes)
    }
  end

  defp raw_payload_shape(raw_payload) do
    raw_payload
    |> Map.keys()
    |> Enum.map(&to_string/1)
    |> Enum.sort()
  end

  defp evidence_artifact(route, %Evidence{} = evidence, %NoEgressPolicy{} = no_egress_policy) do
    %{
      "artifact_ref" => "artifact://execution-plane/lower-simulation/#{route.route_id}",
      "kind" => "lower_simulation_evidence",
      "contract_version" => Evidence.contract_version(),
      "no_egress_policy_ref" => no_egress_policy.policy_ref,
      "negative_evidence_refs" => no_egress_policy.required_negative_evidence,
      "evidence" => Evidence.dump(evidence)
    }
  end
end
