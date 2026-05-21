defmodule ExecutionPlane.Contracts.LaneFactContractTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Contracts.ExecutionEvent.V1, as: ExecutionEvent
  alias ExecutionPlane.Contracts.ExecutionOutcome.V1, as: ExecutionOutcome
  alias ExecutionPlane.Contracts.LaneFact.V1, as: LaneFact
  alias ExecutionPlane.Testkit.ContractFixtures

  test "lane facts cover neutral lower-lane lifecycle phases" do
    for phase <- ["started", "chunk", "frame", "completed", "failed", "timeout", "cancelled"] do
      fact =
        LaneFact.new!(%{
          fact_ref: "lane-fact://route-1/#{phase}/0",
          route_id: "route-1",
          lane_id: "process",
          family: "process",
          protocol: "process",
          phase: phase,
          transport_ref: "transport://execution-plane/process/route-1",
          timestamp: "2026-04-10T11:55:00Z",
          sequence: 0,
          output_byte_size: 0,
          max_output_bytes: 65_536,
          output_hash_ref: "sha256:" <> String.duplicate("1", 64),
          lineage: ContractFixtures.lineage(route_id: "route-1"),
          payload_shape: %{"keys" => ["exit"]},
          evidence_refs: ["evidence://execution-plane/route-1/#{phase}"]
        })

      assert fact.phase == phase
      assert fact.__struct__.new!(fact.__struct__.dump(fact)) == fact
    end
  end

  test "lane facts derive safe bounded shape from execution events and outcomes" do
    started_event =
      ExecutionEvent.new!(%{
        event_id: "event-started-1",
        route_id: "route-1",
        event_type: "dispatch.started",
        timestamp: "2026-04-10T11:55:00Z",
        lineage: ContractFixtures.lineage(route_id: "route-1", event_id: "event-started-1"),
        payload: %{"family" => "http", "protocol" => "http", "timeout_ms" => 750}
      })

    fact =
      LaneFact.from_event!(started_event,
        lane_id: "http",
        protocol: "http",
        transport_ref: "transport://execution-plane/http/route-1",
        max_output_bytes: 65_536
      )

    assert fact.phase == "started"
    assert fact.payload_shape == %{"keys" => ["family", "protocol", "timeout_ms"]}
    refute String.contains?(inspect(LaneFact.dump(fact)), "raw provider body")

    outcome =
      ExecutionOutcome.new!(%{
        route_id: "route-1",
        status: "succeeded",
        family: "http",
        raw_payload: %{
          "status_code" => 200,
          "headers" => %{"content-type" => "application/json"},
          "body" => "raw provider body remains only in ExecutionOutcome"
        },
        artifacts: [],
        metrics: %{},
        lineage: ContractFixtures.lineage(route_id: "route-1")
      })

    terminal_fact =
      LaneFact.from_outcome!(outcome,
        lane_id: "http",
        protocol: "http",
        transport_ref: "transport://execution-plane/http/route-1",
        max_output_bytes: 65_536,
        output_hash_ref: "sha256:" <> String.duplicate("2", 64)
      )

    assert terminal_fact.phase == "completed"

    assert terminal_fact.payload_shape == %{
             "family" => "http",
             "raw_payload_shape" => ["body", "headers", "status_code"]
           }

    refute String.contains?(inspect(LaneFact.dump(terminal_fact)), "raw provider body")
  end

  test "lane facts reject raw credentials, product workflow mutations, and Citadel bypass flags" do
    base =
      LaneFact.dump(
        LaneFact.new!(%{
          fact_ref: "lane-fact://route-1/completed/0",
          route_id: "route-1",
          lane_id: "process",
          family: "process",
          protocol: "process",
          phase: "completed",
          transport_ref: "transport://execution-plane/process/route-1",
          timestamp: "2026-04-10T11:55:00Z",
          sequence: 0,
          output_byte_size: 12,
          max_output_bytes: 65_536,
          output_hash_ref: "sha256:" <> String.duplicate("3", 64),
          lineage: ContractFixtures.lineage(route_id: "route-1"),
          payload_shape: %{"keys" => ["exit"]},
          evidence_refs: []
        })
      )

    for {key, value} <- [
          {"secret", "sk-live"},
          {"workflow_decision", "approve product run"},
          {"citadel_bypass", true},
          {"raw_payload", "raw provider body"}
        ] do
      attrs = put_in(base, ["payload_shape", key], value)

      assert_error_contains("forbidden lane fact payload", fn ->
        LaneFact.new!(attrs)
      end)
    end
  end

  test "lane facts enforce bounded output posture" do
    attrs = %{
      fact_ref: "lane-fact://route-1/chunk/0",
      route_id: "route-1",
      lane_id: "process",
      family: "process",
      protocol: "process",
      phase: "chunk",
      transport_ref: "transport://execution-plane/process/route-1",
      timestamp: "2026-04-10T11:55:00Z",
      sequence: 0,
      output_byte_size: 65_537,
      max_output_bytes: 65_536,
      output_hash_ref: "sha256:" <> String.duplicate("4", 64),
      lineage: ContractFixtures.lineage(route_id: "route-1"),
      payload_shape: %{"keys" => ["stdout"]},
      evidence_refs: []
    }

    assert_error_contains("output_byte_size exceeds max_output_bytes", fn ->
      LaneFact.new!(attrs)
    end)
  end

  defp assert_error_contains(fragment, fun) do
    error = assert_raise(ArgumentError, fun)

    assert Exception.message(error)
           |> String.downcase()
           |> String.contains?(String.downcase(fragment))
  end
end
