defmodule ExecutionPlane.Contracts.PersistencePosture do
  @moduledoc """
  Ref-only persistence posture for lower target and attach surfaces.

  Persistence posture is storage evidence only. It does not grant target attach
  authority and it never persists raw process state.
  """

  alias GroundPlane.PersistencePolicy
  alias GroundPlane.PersistencePolicy.StoreCapability

  @components [
    :target_descriptor,
    :attach_grant,
    :boundary_session,
    :stream_attach_state,
    :cleanup_receipt,
    :execution_evidence,
    :lane_runtime_state,
    :node_state
  ]

  @component_data_classes %{
    target_descriptor: [:target_descriptor],
    attach_grant: [:attach_grant],
    boundary_session: [:boundary_session],
    stream_attach_state: [:stream_attach_state],
    cleanup_receipt: [:cleanup_receipt],
    execution_evidence: [:execution_evidence],
    lane_runtime_state: [:lane_runtime_state],
    node_state: [:node_state]
  }

  @type t :: map()

  @spec components() :: [atom()]
  def components, do: @components

  @spec memory(atom()) :: t()
  def memory(component), do: resolve(component, profile: :mickey_mouse)

  @spec resolve(atom(), map() | keyword()) :: t()
  def resolve(component, attrs \\ []) when component in @components do
    attrs = normalize_attrs(attrs)

    case value(attrs, :persistence_posture) do
      posture when is_map(posture) -> normalize_posture(component, posture)
      _missing -> attrs |> PersistencePolicy.resolve!() |> posture(component)
    end
  end

  @spec preflight(atom(), map() | keyword(), [StoreCapability.t()]) :: :ok | {:error, term()}
  def preflight(component, attrs, capabilities) when component in @components do
    profile = PersistencePolicy.resolve!(attrs)

    PersistencePolicy.preflight(profile, capabilities, fn capability ->
      if component in capability.data_classes or :all in capability.data_classes do
        :ok
      else
        {:error, {:missing_component_capability, component}}
      end
    end)
  end

  @spec memory_capability(atom()) :: StoreCapability.t()
  def memory_capability(component) when component in @components do
    capability!(
      store_ref: component,
      tier: :memory_ephemeral,
      data_classes: data_classes(component),
      adapter: :memory,
      restart_safe?: false
    )
  end

  @spec durable_capability(atom(), atom()) :: StoreCapability.t()
  def durable_capability(component, tier \\ :postgres_shared) when component in @components do
    capability!(
      store_ref: component,
      tier: tier,
      data_classes: data_classes(component),
      adapter: tier,
      restart_safe?: tier in [:local_restart_safe, :postgres_shared, :temporal_durable]
    )
  end

  @spec durable?(t()) :: boolean()
  def durable?(posture) when is_map(posture), do: value(posture, :durable?) == true

  defp posture(%PersistencePolicy.Profile{} = profile, component) do
    tier = profile.default_tier
    store_set = profile.store_set

    %{
      component: component,
      persistence_profile_ref: ref("persistence-profile", profile.id),
      persistence_tier_ref: ref("persistence-tier", tier),
      capture_level_ref: ref("capture-level", profile.capture_level),
      store_set_ref: ref("store-set", store_set.id),
      store_partition_ref: partition_ref(profile),
      retention_policy_ref: retention_ref(profile),
      debug_tap_ref: debug_tap_ref(profile),
      persistence_receipt_ref: receipt_ref(component, profile.id),
      store_ref: ref("store", tier),
      durable?: profile.durable?,
      restart_durability_claim: restart_claim(profile),
      raw_process_state_persistence?: false
    }
  end

  defp normalize_posture(component, posture) do
    default = memory(component)

    %{
      component: component,
      persistence_profile_ref:
        string_or_default(posture, :persistence_profile_ref, default.persistence_profile_ref),
      persistence_tier_ref:
        string_or_default(posture, :persistence_tier_ref, default.persistence_tier_ref),
      capture_level_ref:
        string_or_default(posture, :capture_level_ref, default.capture_level_ref),
      store_set_ref: string_or_default(posture, :store_set_ref, default.store_set_ref),
      store_partition_ref: optional_string(posture, :store_partition_ref),
      retention_policy_ref:
        string_or_default(posture, :retention_policy_ref, default.retention_policy_ref),
      debug_tap_ref: optional_string(posture, :debug_tap_ref),
      persistence_receipt_ref:
        string_or_default(posture, :persistence_receipt_ref, default.persistence_receipt_ref),
      store_ref: string_or_default(posture, :store_ref, default.store_ref),
      durable?: value(posture, :durable?) == true,
      restart_durability_claim: value(posture, :restart_durability_claim) || :none,
      raw_process_state_persistence?: false
    }
  end

  defp capability!(attrs) do
    case StoreCapability.new(attrs) do
      {:ok, capability} -> capability
      {:error, reason} -> raise ArgumentError, message: inspect(reason)
    end
  end

  defp data_classes(component), do: Map.fetch!(@component_data_classes, component)

  defp ref(prefix, value) when is_atom(value), do: "#{prefix}://#{Atom.to_string(value)}"

  defp receipt_ref(component, profile_id),
    do:
      "persistence-receipt://execution-plane/#{Atom.to_string(component)}/#{Atom.to_string(profile_id)}"

  defp partition_ref(%PersistencePolicy.Profile{durable?: true, default_tier: tier}),
    do: "store-partition://#{Atom.to_string(tier)}/default"

  defp partition_ref(%PersistencePolicy.Profile{}), do: nil

  defp retention_ref(%PersistencePolicy.Profile{metadata: %{restart_claim: :none}}),
    do: "retention://process-lifetime"

  defp retention_ref(%PersistencePolicy.Profile{default_tier: tier}),
    do: "retention://#{Atom.to_string(tier)}"

  defp debug_tap_ref(%PersistencePolicy.Profile{debug_tap: PersistencePolicy.DebugTap.Noop}),
    do: nil

  defp debug_tap_ref(%PersistencePolicy.Profile{debug_tap: module}),
    do: "debug-tap://#{inspect(module)}"

  defp restart_claim(%PersistencePolicy.Profile{metadata: metadata}) do
    Map.get(metadata, :restart_claim, :none)
  end

  defp normalize_attrs(attrs) when is_list(attrs), do: Map.new(attrs)
  defp normalize_attrs(attrs) when is_map(attrs), do: attrs

  defp string_or_default(attrs, key, default) do
    case value(attrs, key) do
      current when is_binary(current) and current != "" -> current
      _other -> default
    end
  end

  defp optional_string(attrs, key) do
    case value(attrs, key) do
      current when is_binary(current) and current != "" -> current
      _other -> nil
    end
  end

  defp value(attrs, field) when is_atom(field),
    do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
end
