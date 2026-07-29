defmodule ExecutionPlane.Node.Server do
  @moduledoc false

  use GenServer

  alias ExecutionPlane.ActiveExecution
  alias ExecutionPlane.Admission.{Decision, Rejection, Request}
  alias ExecutionPlane.Contracts.PersistencePosture
  alias ExecutionPlane.Evidence
  alias ExecutionPlane.ExecutionRef
  alias ExecutionPlane.ExecutionRequest
  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.Lane.Capabilities
  alias ExecutionPlane.Node.{ExecutionRegistry, ExecutionSupervisor, ExecutionWorker}
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
            persistence_posture: %{},
            targets: %{},
            target_clients: %{},
            executions: %{},
            lane_opts: %{},
            execution_registry: ExecutionRegistry,
            execution_supervisor: ExecutionSupervisor,
            execution_event_limit: 256,
            execution_cleanup_after_ms: 60_000

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

  def start_execution(server, request, opts),
    do: GenServer.call(server, {:start_execution, request, opts}, call_timeout(opts))

  def subscribe_execution(server, execution_ref, subscriber, opts),
    do:
      GenServer.call(
        server,
        {:active, :subscribe, execution_ref, subscriber, opts},
        call_timeout(opts)
      )

  def send_execution_input(server, execution_ref, input, opts),
    do:
      GenServer.call(
        server,
        {:active, :send_input, execution_ref, input, opts},
        call_timeout(opts)
      )

  def end_execution_input(server, execution_ref, opts),
    do: GenServer.call(server, {:active, :end_input, execution_ref, opts}, call_timeout(opts))

  def execution_status(server, execution_ref, opts),
    do: GenServer.call(server, {:active, :status, execution_ref, opts}, call_timeout(opts))

  def cancel_execution(server, execution_ref, opts),
    do: GenServer.call(server, {:active, :cancel, execution_ref, opts}, call_timeout(opts))

  @impl true
  def init(opts) do
    {:ok,
     %__MODULE__{
       node_id: Keyword.get(opts, :node_id, "node-#{System.system_time(:millisecond)}"),
       persistence_posture: PersistencePosture.resolve(:node_state, opts),
       execution_registry: Keyword.get(opts, :execution_registry, ExecutionRegistry),
       execution_supervisor: Keyword.get(opts, :execution_supervisor, ExecutionSupervisor),
       execution_event_limit: Keyword.get(opts, :execution_event_limit, 256),
       execution_cleanup_after_ms: Keyword.get(opts, :execution_cleanup_after_ms, 60_000)
     }}
  end

  @impl true
  def handle_call({:register_lane, adapter, opts}, _from, state) when is_atom(adapter) do
    lane_id = adapter.lane_id() |> to_string()

    lane_opts =
      opts
      |> Keyword.drop([:server, :timeout])
      |> Keyword.get(:active_options, [])

    {:reply, :ok,
     %{
       state
       | lanes: Map.put(state.lanes, lane_id, adapter),
         lane_opts: Map.put(state.lane_opts, lane_id, lane_opts)
     }}
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
        registration_complete: state.registration_complete?,
        metadata: %{
          "persistence_posture" =>
            ExecutionPlane.Contracts.stringify_keys(state.persistence_posture)
        }
      )

    {:reply, {:ok, descriptor}, state}
  end

  def handle_call({:admit, request, opts}, _from, state) do
    request = Request.new!(request)
    {reply, next_state} = admit_request(state, request, opts)
    {:reply, reply, next_state}
  end

  def handle_call({:execute, request, opts}, from, state) do
    request = Request.new!(request)

    case admit_request(state, request, opts) do
      {{:ok, %Decision{} = decision}, admitted_state} ->
        case start_active_worker(admitted_state, request, decision, opts) do
          {:ok, active} ->
            start_one_shot_waiter(admitted_state, active, opts, from)

            next_state = %{
              admitted_state
              | executions:
                  Map.put(admitted_state.executions, decision.execution_ref, %{
                    active?: true,
                    request: request,
                    decision: decision
                  })
            }

            {:noreply, next_state}

          {:error, reason} ->
            {:reply, {:error, failed_execution_result(request, reason)}, admitted_state}
        end

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

  def handle_call({:stream, request, _opts}, _from, state) do
    request = Request.new!(request)

    rejection =
      Rejection.new!(
        request_id: request.request_id,
        reason: "active_runtime_client_required",
        message: "legacy stream dispatch is retired; use ExecutionPlane.Runtime.Client"
      )

    {:reply, {:error, rejection}, state}
  end

  def handle_call({:cancel, execution_ref, opts}, _from, state) do
    ref = normalize_execution_ref(execution_ref)

    state.executions
    |> Map.get(ref)
    |> case do
      nil ->
        {:reply, {:error, :unknown_execution_ref}, state}

      %{active?: true} = execution ->
        reply =
          with {:ok, entry} <- active_entry(state, ref) do
            ExecutionWorker.cancel(
              entry.worker,
              Keyword.get(opts, :reason, "cancelled"),
              Keyword.get(opts, :fence)
            )
          end

        evidence(
          state,
          execution.request,
          "execution.cancelled",
          %{execution_ref: ref, cancel_result: inspect(reply)},
          execution.decision
        )

        {:reply, reply, state}

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

  def handle_call({:start_execution, request, opts}, _from, state) do
    request = Request.new!(request)

    case admit_request(state, request, opts) do
      {{:ok, %Decision{} = decision}, admitted_state} ->
        {:reply, start_active_worker(admitted_state, request, decision, opts), admitted_state}

      {{:error, %Rejection{} = rejection}, rejected_state} ->
        {:reply, {:error, rejection}, rejected_state}
    end
  end

  def handle_call({:active, :subscribe, ref, subscriber, opts}, _from, state) do
    reply =
      with {:ok, entry} <- active_entry(state, ref),
           :ok <- validate_active_fence(entry, opts) do
        ExecutionWorker.subscribe(
          entry.worker,
          subscriber,
          Keyword.get(opts, :fence)
        )
      end

    {:reply, reply, state}
  end

  def handle_call({:active, :send_input, ref, input, opts}, _from, state) do
    reply =
      with {:ok, entry} <- active_entry(state, ref),
           :ok <- validate_active_fence(entry, opts) do
        ExecutionWorker.send_input(
          entry.worker,
          input,
          Keyword.get(opts, :fence)
        )
      end

    {:reply, reply, state}
  end

  def handle_call({:active, :end_input, ref, opts}, _from, state) do
    reply =
      with {:ok, entry} <- active_entry(state, ref),
           :ok <- validate_active_fence(entry, opts) do
        ExecutionWorker.end_input(entry.worker, Keyword.get(opts, :fence))
      end

    {:reply, reply, state}
  end

  def handle_call({:active, :status, ref, opts}, _from, state) do
    reply =
      with {:ok, entry} <- active_entry(state, ref),
           :ok <- validate_active_fence(entry, opts) do
        ExecutionWorker.status(entry.worker, Keyword.get(opts, :fence))
      end

    {:reply, reply, state}
  end

  def handle_call({:active, :cancel, ref, opts}, _from, state) do
    reply =
      with {:ok, entry} <- active_entry(state, ref),
           :ok <- validate_active_fence(entry, opts) do
        ExecutionWorker.cancel(
          entry.worker,
          Keyword.get(opts, :reason, "cancelled"),
          Keyword.get(opts, :fence)
        )
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_info(
        {:execution_plane_active_terminal, request, decision, result},
        state
      ) do
    evidence(state, request, "execution.completed", %{result: result}, decision)
    {:noreply, state}
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
    |> targets_for_placement(request.placement)
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

  defp targets_for_placement(targets, %{metadata: metadata}) when is_map(metadata) do
    case Map.get(metadata, "target_id", Map.get(metadata, :target_id)) do
      target_id when is_binary(target_id) and target_id != "" ->
        case Map.fetch(targets, target_id) do
          {:ok, target} -> [{target_id, target}]
          :error -> []
        end

      _other ->
        targets
    end
  end

  defp targets_for_placement(targets, _placement), do: targets

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

  defp execution_request(request, decision, state) do
    ExecutionRequest.new!(
      execution_ref: decision.execution_ref,
      admission_request: request,
      target_descriptor: decision.target_id && Map.fetch!(state.targets, decision.target_id),
      lane_id: request.lane_id,
      operation: request.operation,
      payload: request.payload,
      provenance: request.provenance,
      metadata: %{
        "node_persistence_posture" =>
          ExecutionPlane.Contracts.stringify_keys(state.persistence_posture)
      }
    )
  end

  defp dispatch_binding(state, %Decision{target_id: nil, lane_id: lane_id}) do
    {ExecutionPlane.Node.TargetClient.Adapter, Map.get(state.lane_opts, lane_id, []),
     Map.fetch!(state.lanes, lane_id)}
  end

  defp dispatch_binding(state, %Decision{target_id: target_id, lane_id: lane_id}) do
    {target_client, client_opts} = Map.fetch!(state.target_clients, target_id)

    {target_client, Keyword.merge(Map.get(state.lane_opts, lane_id, []), client_opts),
     Map.fetch!(state.lanes, lane_id)}
  end

  defp start_active_worker(state, request, decision, _opts) do
    execution_request = execution_request(request, decision, state)
    {target_client, client_opts, lane_adapter} = dispatch_binding(state, decision)
    generation = :erlang.unique_integer([:positive, :monotonic])

    args = [
      execution_ref: decision.execution_ref,
      owner: self(),
      request: execution_request,
      decision: decision,
      node_id: state.node_id,
      generation: generation,
      target_client: target_client,
      client_opts: client_opts,
      lane_adapter: lane_adapter,
      event_limit: state.execution_event_limit,
      cleanup_after_ms: state.execution_cleanup_after_ms
    ]

    with {:ok, worker} <-
           ExecutionSupervisor.start_worker(state.execution_supervisor, args),
         :ok <-
           register_active_worker(
             state,
             state.execution_registry,
             decision.execution_ref,
             worker,
             decision.target_id,
             generation
           ) do
      evidence(state, request, "execution.started", execution_request, decision)

      {:ok,
       ActiveExecution.new!(%{
         execution_ref: decision.execution_ref,
         session_ref: "session://execution-plane/#{decision.execution_ref}",
         admission_decision_ref:
           "admission://execution-plane/#{request.request_id}/#{decision.execution_ref}",
         node_id: state.node_id,
         lane_id: request.lane_id,
         state: "accepted",
         started_at: DateTime.utc_now(),
         fence: generation
       })}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp register_active_worker(state, registry, ref, worker, target_id, generation) do
    case ExecutionRegistry.register(registry, ref, worker, target_id, generation) do
      :ok ->
        :ok

      {:error, _reason} = error ->
        _ = ExecutionSupervisor.terminate_worker(state.execution_supervisor, worker)
        error
    end
  end

  defp active_entry(state, execution_ref) do
    ref = normalize_execution_ref(execution_ref)
    ExecutionRegistry.lookup(state.execution_registry, ref)
  end

  defp validate_active_fence(entry, opts) do
    case Keyword.get(opts, :fence) do
      nil -> :ok
      fence when fence == entry.generation -> :ok
      _other -> {:error, :stale_execution_fence}
    end
  end

  defp start_one_shot_waiter(state, active, opts, from) do
    registry = state.execution_registry
    timeout = Keyword.get(opts, :timeout, 30_000)
    deadline = System.monotonic_time(:millisecond) + timeout

    Task.start(fn ->
      reply =
        with {:ok, entry} <- ExecutionRegistry.lookup(registry, active.execution_ref.ref),
             :ok <- ExecutionWorker.subscribe(entry.worker, self(), active.fence) do
          await_one_shot_result(active.execution_ref.ref, deadline)
        end

      GenServer.reply(from, reply)
    end)
  end

  defp await_one_shot_result(ref, deadline) do
    timeout = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:execution_plane_runtime, ^ref,
       %ExecutionPlane.Runtime.Event{kind: "receipt", payload: payload}} ->
        result = one_shot_result(payload)

        if result.status == "succeeded" do
          {:ok, result}
        else
          {:error, result}
        end

      {:execution_plane_runtime, ^ref, %ExecutionPlane.Runtime.Event{}} ->
        await_one_shot_result(ref, deadline)
    after
      timeout ->
        {:error,
         ExecutionResult.new!(
           execution_ref: ref,
           status: "failed",
           error: %{"reason" => "active execution timed out"}
         )}
    end
  end

  defp one_shot_result(payload) do
    payload
    |> Map.get("execution_result", Map.get(payload, :execution_result))
    |> ExecutionResult.new!()
  end

  defp failed_execution_result(request, reason) do
    ExecutionResult.new!(
      execution_ref: ExecutionRef.new!().ref,
      status: "failed",
      error: %{"reason" => inspect(reason)},
      provenance: request.provenance
    )
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
        payload: ExecutionPlane.Boundary.dump_value(payload),
        persistence_posture:
          PersistencePosture.resolve(:execution_evidence, %{
            persistence_posture: state.persistence_posture
          })
      )

    Enum.each(state.evidence_sinks, fn {_id, sink} -> sink.emit(evidence, []) end)
    evidence
  end

  defp normalize_execution_ref(%ExecutionRef{ref: ref}), do: ref
  defp normalize_execution_ref(ref) when is_binary(ref), do: ref
  defp normalize_execution_ref(%{"ref" => ref}), do: ref
  defp normalize_execution_ref(%{ref: ref}), do: ref

  defp call_timeout(opts) do
    case Keyword.get(opts, :timeout, 5_000) do
      timeout when is_integer(timeout) and timeout > 0 -> timeout
      _other -> 5_000
    end
  end
end
