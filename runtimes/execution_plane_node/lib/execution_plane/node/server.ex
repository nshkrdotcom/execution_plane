defmodule ExecutionPlane.Node.Server do
  @moduledoc false

  use GenServer

  alias ExecutionPlane.Admission.{Decision, Rejection, Request}
  alias ExecutionPlane.Evidence
  alias ExecutionPlane.ExecutionRef
  alias ExecutionPlane.ExecutionRequest
  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.Lane.Capabilities
  alias ExecutionPlane.Provenance
  alias ExecutionPlane.Runtime.NodeDescriptor
  alias ExecutionPlane.Sandbox.AcceptableAttestation
  alias ExecutionPlane.Target.Attestation

  defstruct node_id: nil,
            lanes: %{},
            target_verifiers: %{},
            evidence_sinks: %{},
            authority_verifier: nil,
            registration_complete?: false,
            targets: %{},
            target_clients: %{},
            executions: %{}

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def register_lane(server, adapter, opts),
    do: GenServer.call(server, {:register_lane, adapter, opts})

  def register_target_verifier(server, verifier, opts),
    do: GenServer.call(server, {:register_target_verifier, verifier, opts})

  def register_evidence_sink(server, sink, opts),
    do: GenServer.call(server, {:register_evidence_sink, sink, opts})

  def register_authority_verifier(server, verifier, opts),
    do: GenServer.call(server, {:register_authority_verifier, verifier, opts})

  def complete_registration(server, opts),
    do: GenServer.call(server, {:complete_registration, opts})

  def connect_target(server, attestation, target_client, opts),
    do: GenServer.call(server, {:connect_target, attestation, target_client, opts})

  def describe(server, opts), do: GenServer.call(server, {:describe, opts})
  def admit(server, request, opts), do: GenServer.call(server, {:admit, request, opts})

  def execute(server, request, opts),
    do: GenServer.call(server, {:execute, request, opts}, Keyword.get(opts, :timeout, 30_000))

  def stream(server, request, opts), do: GenServer.call(server, {:stream, request, opts})

  def cancel(server, execution_ref, opts),
    do: GenServer.call(server, {:cancel, execution_ref, opts})

  @impl true
  def init(opts) do
    {:ok,
     %__MODULE__{
       node_id: Keyword.get(opts, :node_id, "node-#{System.system_time(:millisecond)}")
     }}
  end

  @impl true
  def handle_call({:register_lane, adapter, _opts}, _from, state) when is_atom(adapter) do
    lane_id = adapter.lane_id() |> to_string()
    {:reply, :ok, %{state | lanes: Map.put(state.lanes, lane_id, adapter)}}
  end

  def handle_call({:register_target_verifier, verifier, _opts}, _from, state)
      when is_atom(verifier) do
    {:reply, :ok,
     %{
       state
       | target_verifiers: Map.put(state.target_verifiers, verifier.verifier_id(), verifier)
     }}
  end

  def handle_call({:register_evidence_sink, sink, _opts}, _from, state) when is_atom(sink) do
    {:reply, :ok, %{state | evidence_sinks: Map.put(state.evidence_sinks, sink.sink_id(), sink)}}
  end

  def handle_call({:register_authority_verifier, verifier, _opts}, _from, state)
      when is_atom(verifier) do
    {:reply, :ok, %{state | authority_verifier: verifier}}
  end

  def handle_call({:complete_registration, _opts}, _from, state) do
    {:reply, :ok, %{state | registration_complete?: true}}
  end

  def handle_call({:connect_target, attestation, target_client, opts}, _from, state) do
    attestation = Attestation.new!(attestation)

    with {:ok, verifier} <- target_verifier_for(state, attestation),
         {:ok, descriptor} <- verifier.verify(attestation, opts) do
      target_id = descriptor.target_id

      next_state = %{
        state
        | targets: Map.put(state.targets, target_id, descriptor),
          target_clients: Map.put(state.target_clients, target_id, {target_client, opts})
      }

      {:reply, {:ok, descriptor}, next_state}
    else
      {:error, %Rejection{} = rejection} ->
        {:reply, {:error, rejection}, state}

      {:error, reason} ->
        {:reply, {:error, Rejection.new(:target_attestation_unverifiable, inspect(reason))},
         state}
    end
  end

  def handle_call({:describe, _opts}, _from, state) do
    descriptor =
      NodeDescriptor.new!(
        node_id: state.node_id,
        registered_lanes: lane_descriptors(state),
        registered_target_verifiers: target_verifier_descriptors(state),
        verified_targets: Enum.map(state.targets, fn {_id, descriptor} -> descriptor end),
        authority_verifier: authority_verifier_id(state),
        registration_complete: state.registration_complete?
      )

    {:reply, {:ok, descriptor}, state}
  end

  def handle_call({:admit, request, opts}, _from, state) do
    request = Request.new!(request)
    {reply, next_state} = admit_request(state, request, opts)
    {:reply, reply, next_state}
  end

  def handle_call({:execute, request, opts}, _from, state) do
    request = Request.new!(request)

    case admit_request(state, request, opts) do
      {{:ok, %Decision{} = decision}, admitted_state} ->
        dispatch_execution(admitted_state, request, decision, opts)

      {{:error, %Rejection{} = rejection}, rejected_state} ->
        result =
          ExecutionResult.new!(
            execution_ref: ExecutionRef.new!().ref,
            status: "rejected",
            error: Rejection.dump(rejection),
            provenance: request.provenance
          )

        {:reply, {:error, result}, rejected_state}
    end
  end

  def handle_call({:stream, request, opts}, _from, state) do
    request = Request.new!(request)

    case admit_request(state, request, opts) do
      {{:ok, %Decision{} = decision}, admitted_state} ->
        execution_request = execution_request(request, decision, admitted_state)
        {target_client, client_opts, lane_adapter} = dispatch_binding(admitted_state, decision)

        reply =
          target_client.stream(
            execution_request,
            Keyword.merge(client_opts, Keyword.put(opts, :lane_adapter, lane_adapter))
          )

        {:reply, reply, admitted_state}

      {{:error, %Rejection{} = rejection}, rejected_state} ->
        {:reply, {:error, rejection}, rejected_state}
    end
  end

  def handle_call({:cancel, execution_ref, opts}, _from, state) do
    ref = normalize_execution_ref(execution_ref)

    state.executions
    |> Map.get(ref)
    |> case do
      nil ->
        {:reply, {:error, :unknown_execution_ref}, state}

      execution ->
        reply =
          execution.target_client.cancel(
            ExecutionRef.new!(ref: ref),
            opts ++ execution.client_opts
          )

        evidence(
          state,
          execution.request,
          "execution.cancelled",
          %{execution_ref: ref, cancel_result: inspect(reply)},
          execution.decision
        )

        {:reply, reply, state}
    end
  end

  defp admit_request(state, %Request{} = request, opts) do
    cond do
      not ExecutionPlane.ContractVersion.compatible?(request.contract_version) ->
        reject(
          state,
          request,
          :contract_version_mismatch,
          "request contract version is not supported"
        )

      Provenance.direct?(request.provenance) ->
        admit_direct(state, request)

      not state.registration_complete? ->
        reject(state, request, :registration_incomplete, "node registration is not complete")

      is_nil(state.authority_verifier) ->
        reject(
          state,
          request,
          :authority_verifier_missing,
          "governed admission requires an authority verifier"
        )

      not Map.has_key?(state.lanes, request.lane_id) ->
        reject(state, request, :lane_not_registered, "requested lane is not registered")

      true ->
        with :ok <- verify_authority(state, request, opts),
             {:ok, target, attestation_class} <- select_target(state, request) do
          decision =
            Decision.new!(
              request_id: request.request_id,
              execution_ref: ExecutionRef.new!().ref,
              target_id: target.target_id,
              lane_id: request.lane_id,
              attestation_class: attestation_class
            )

          evidence(state, request, "admission.accepted", decision, decision)
          evidence(state, request, "target.selected", target, decision)
          {{:ok, decision}, state}
        else
          {:error, %Rejection{} = rejection} ->
            evidence(state, request, "admission.rejected", rejection)
            {{:error, rejection}, state}
        end
    end
  end

  defp admit_direct(state, %Request{} = request) do
    if Map.has_key?(state.lanes, request.lane_id) do
      decision =
        Decision.new!(
          request_id: request.request_id,
          execution_ref: ExecutionRef.new!().ref,
          lane_id: request.lane_id,
          reason: "direct lower-lane-owner execution"
        )

      {{:ok, decision}, state}
    else
      reject(state, request, :lane_not_registered, "requested direct lane is not registered")
    end
  end

  defp verify_authority(state, request, opts) do
    case request.authority_ref do
      nil ->
        {:error,
         Rejection.new(:authority_ref_missing, "governed admission requires authority_ref")}

      authority_ref ->
        state.authority_verifier.verify(authority_ref, opts)
        |> case do
          {:ok, _claims} -> :ok
          {:error, %Rejection{} = rejection} -> {:error, rejection}
          {:error, reason} -> {:error, Rejection.new(:authority_rejected, inspect(reason))}
        end
    end
  end

  defp select_target(state, request) do
    state.targets
    |> Enum.find_value(fn {_id, target} ->
      matching_attestation_class(target, request.acceptable_attestation, request.lane_id)
    end)
    |> case do
      {target, class} ->
        {:ok, target, class}

      nil ->
        {:error,
         Rejection.new(
           :no_satisfying_attested_target,
           "no verified target satisfies acceptable attestation for requested lane"
         )}
    end
  end

  defp matching_attestation_class(target, acceptable, lane_id) do
    if target.lane_id == lane_id do
      acceptable
      |> AcceptableAttestation.intersect(target.attested_capability_classes)
      |> case do
        [class | _rest] -> {target, class}
        [] -> nil
      end
    end
  end

  defp dispatch_execution(state, request, decision, opts) do
    execution_request = execution_request(request, decision, state)
    {target_client, client_opts, lane_adapter} = dispatch_binding(state, decision)
    final_opts = Keyword.merge(client_opts, Keyword.put(opts, :lane_adapter, lane_adapter))

    evidence(state, request, "execution.started", execution_request, decision)
    reply = target_client.execute(execution_request, final_opts)
    evidence(state, request, "execution.completed", execution_reply_payload(reply), decision)

    next_state = %{
      state
      | executions:
          Map.put(state.executions, decision.execution_ref, %{
            target_id: decision.target_id,
            target_client: target_client,
            client_opts: client_opts,
            request: request,
            decision: decision
          })
    }

    {:reply, reply, next_state}
  end

  defp execution_request(request, decision, state) do
    ExecutionRequest.new!(
      execution_ref: decision.execution_ref,
      admission_request: request,
      target_descriptor: decision.target_id && Map.fetch!(state.targets, decision.target_id),
      lane_id: request.lane_id,
      operation: request.operation,
      payload: request.payload,
      provenance: request.provenance
    )
  end

  defp dispatch_binding(state, %Decision{target_id: nil, lane_id: lane_id}) do
    {ExecutionPlane.Node.TargetClient.Adapter, [], Map.fetch!(state.lanes, lane_id)}
  end

  defp dispatch_binding(state, %Decision{target_id: target_id, lane_id: lane_id}) do
    {target_client, client_opts} = Map.fetch!(state.target_clients, target_id)
    {target_client, client_opts, Map.fetch!(state.lanes, lane_id)}
  end

  defp reject(state, request, reason, message) do
    rejection =
      Rejection.new!(
        request_id: request.request_id,
        reason: to_string(reason),
        message: message
      )

    evidence(state, request, "admission.rejected", rejection)
    {{:error, rejection}, state}
  end

  defp target_verifier_for(state, attestation) do
    state.target_verifiers
    |> Enum.find_value(fn {_id, verifier} ->
      if verifier.handles?(attestation), do: verifier
    end)
    |> case do
      nil -> {:error, :no_target_verifier}
      verifier -> {:ok, verifier}
    end
  end

  defp lane_descriptors(state) do
    Enum.map(state.lanes, fn {lane_id, adapter} ->
      adapter.capabilities()
      |> Capabilities.dump()
      |> Map.put("lane_id", lane_id)
    end)
  end

  defp target_verifier_descriptors(state) do
    Enum.map(state.target_verifiers, fn {verifier_id, verifier} ->
      %{
        "verifier_id" => verifier_id,
        "attestation_types" => verifier.attestation_types(),
        "capability_classes" => verifier.capability_classes()
      }
    end)
  end

  defp authority_verifier_id(%{authority_verifier: nil}), do: nil
  defp authority_verifier_id(%{authority_verifier: verifier}), do: verifier.verifier_id()

  defp execution_reply_payload({:ok, %ExecutionResult{} = result}) do
    %{reply: "ok", status: result.status, result: result}
  end

  defp execution_reply_payload({:error, %ExecutionResult{} = result}) do
    %{reply: "error", status: result.status, result: result}
  end

  defp execution_reply_payload(reply), do: %{reply: inspect(reply)}

  defp evidence(state, request, event_type, payload, decision \\ nil) do
    target = decision && decision.target_id && Map.get(state.targets, decision.target_id)

    evidence =
      Evidence.new!(
        evidence_type: event_type,
        execution_ref: decision && decision.execution_ref,
        request_id: request.request_id,
        lane_id: request.lane_id,
        policy_bundle_hash: request.sandbox_profile && request.sandbox_profile.bundle_hash,
        target_id: decision && decision.target_id,
        target_verifier_id: target && target.verifier_id,
        attestation_class: decision && decision.attestation_class,
        authority_verifier_id: authority_verifier_id(state),
        payload: ExecutionPlane.Boundary.dump_value(payload)
      )

    Enum.each(state.evidence_sinks, fn {_id, sink} -> sink.emit(evidence, []) end)
    evidence
  end

  defp normalize_execution_ref(%ExecutionRef{ref: ref}), do: ref
  defp normalize_execution_ref(ref) when is_binary(ref), do: ref
  defp normalize_execution_ref(%{"ref" => ref}), do: ref
  defp normalize_execution_ref(%{ref: ref}), do: ref
end
