defmodule ExecutionPlane.LaneSupportPersistenceTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.LaneSupport

  test "lane support emits memory-default and durable persistence posture metadata" do
    lineage = LaneSupport.build_lineage("process", %{idempotency_key: "idem-lane-posture"})

    envelope =
      LaneSupport.build_envelope("process", "process", "process.run", lineage, %{
        profile: :ops_durable
      })

    posture = envelope.extensions["execution_plane"]["persistence_posture"]

    assert posture["component"] == :lane_runtime_state
    assert posture["persistence_profile_ref"] == "persistence-profile://ops_durable"
    assert posture["raw_process_state_persistence?"] == false

    route =
      LaneSupport.build_route(
        "process",
        "process",
        "process",
        "local",
        %{"target_id" => "target-1"},
        1_000,
        lineage,
        %{profile: :ops_durable}
      )

    assert route.resolved_target["persistence_posture"]["component"] == :target_descriptor
    assert route.resolved_target["persistence_posture"]["durable?"] == true
  end
end
