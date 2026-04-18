defmodule ExecutionPlane.LaneSupport do
  @moduledoc false

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.ExecutionIntentEnvelope.V1, as: ExecutionIntentEnvelope
  alias ExecutionPlane.Contracts.ExecutionRoute.V1, as: ExecutionRoute

  @required_lineage_keys [
    :tenant_id,
    :trace_id,
    :request_id,
    :decision_id,
    :boundary_session_id,
    :attempt_ref,
    :route_id,
    :idempotency_key
  ]

  @kernel_opt_keys [:emit, :now, :timeout_ms]

  @spec build_lineage(String.t(), map() | keyword() | nil) :: Contracts.lineage_t()
  def build_lineage(family, overrides \\ %{}) when is_binary(family) do
    token = Integer.to_string(System.unique_integer([:positive, :monotonic]))
    overrides = normalize_optional_attrs(overrides)

    %{
      tenant_id: fetch_or_default(overrides, :tenant_id, "tenant:auto"),
      trace_id: fetch_or_default(overrides, :trace_id, default_trace_id()),
      request_id: fetch_or_default(overrides, :request_id, "#{family}-request-#{token}"),
      decision_id: fetch_or_default(overrides, :decision_id, "#{family}-decision-#{token}"),
      boundary_session_id:
        fetch_or_default(overrides, :boundary_session_id, "#{family}-boundary-session-#{token}"),
      attempt_ref: fetch_or_default(overrides, :attempt_ref, "attempt://#{family}/#{token}"),
      route_id: fetch_or_default(overrides, :route_id, "#{family}-route-#{token}"),
      idempotency_key:
        fetch_or_default(overrides, :idempotency_key, "#{family}-idempotency-#{token}")
    }
    |> maybe_put_extensions(Contracts.fetch_value(overrides, :extensions))
    |> Contracts.normalize_lineage!(@required_lineage_keys)
  end

  @spec build_envelope(
          String.t(),
          String.t(),
          String.t(),
          Contracts.lineage_t(),
          map() | keyword() | nil
        ) :: ExecutionIntentEnvelope.t()
  def build_envelope(family, protocol, capability, lineage, attrs \\ %{}) do
    attrs = normalize_optional_attrs(attrs)
    token = Integer.to_string(System.unique_integer([:positive, :monotonic]))

    ExecutionIntentEnvelope.new!(%{
      intent_id: fetch_or_default(attrs, :intent_id, "#{family}-intent-#{token}"),
      family: family,
      protocol: protocol,
      trace_id: fetch_or_default(attrs, :trace_id, lineage.trace_id),
      idempotency_key: lineage.idempotency_key,
      boundary_session_id: lineage.boundary_session_id,
      decision_id: lineage.decision_id,
      lease_ref: Contracts.fetch_value(attrs, :lease_ref),
      route_template_ref: Contracts.fetch_value(attrs, :route_template_ref),
      credential_handle_refs: Contracts.fetch_value(attrs, :credential_handle_refs) || [],
      attempt_ref: lineage.attempt_ref,
      deadline_at: Contracts.fetch_value(attrs, :deadline_at),
      cancellation_ref: Contracts.fetch_value(attrs, :cancellation_ref),
      requested_capabilities: requested_capabilities(attrs, capability),
      extensions: Contracts.fetch_value(attrs, :extensions) || %{}
    })
  end

  @spec build_route(
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          map(),
          integer() | nil,
          Contracts.lineage_t(),
          map() | keyword() | nil
        ) :: ExecutionRoute.t()
  def build_route(
        family,
        protocol,
        transport_family,
        placement_family,
        target,
        timeout_ms,
        lineage,
        attrs \\ %{}
      ) do
    attrs = normalize_optional_attrs(attrs)
    budget = route_budget(attrs, timeout_ms)

    ExecutionRoute.new!(%{
      route_id: lineage.route_id,
      family: family,
      protocol: protocol,
      transport_family: fetch_or_default(attrs, :transport_family, transport_family),
      placement_family: fetch_or_default(attrs, :placement_family, placement_family),
      resolved_target:
        attrs
        |> Contracts.fetch_optional_map!(:resolved_target, %{})
        |> Map.merge(target),
      resolved_budget: budget,
      lineage: lineage
    })
  end

  @spec kernel_opts(keyword()) :: keyword()
  def kernel_opts(opts) when is_list(opts) do
    Keyword.take(opts, @kernel_opt_keys)
  end

  defp requested_capabilities(attrs, default_capability) do
    attrs
    |> Contracts.fetch_optional_list!(:requested_capabilities, [default_capability])
    |> Kernel.++([default_capability])
    |> Enum.uniq()
  end

  defp route_budget(attrs, timeout_ms) do
    attrs
    |> Contracts.fetch_optional_map!(:resolved_budget, %{})
    |> maybe_put_timeout(timeout_ms)
  end

  defp maybe_put_timeout(budget, timeout_ms) when is_integer(timeout_ms) and timeout_ms > 0 do
    Map.put(budget, "timeout_ms", timeout_ms)
  end

  defp maybe_put_timeout(budget, _timeout_ms), do: budget

  defp fetch_or_default(attrs, key, default) do
    Contracts.fetch_value(attrs, key) || default
  end

  defp default_trace_id do
    Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
  end

  defp maybe_put_extensions(lineage, nil), do: lineage
  defp maybe_put_extensions(lineage, extensions), do: Map.put(lineage, :extensions, extensions)

  defp normalize_optional_attrs(nil), do: %{}
  defp normalize_optional_attrs(attrs), do: Contracts.normalize_attrs(attrs)
end
