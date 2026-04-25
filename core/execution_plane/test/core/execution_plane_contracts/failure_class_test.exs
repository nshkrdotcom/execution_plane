defmodule ExecutionPlane.Contracts.FailureClassTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Contracts.Failure
  alias ExecutionPlane.Contracts.FailureClass

  test "the required failure classes are frozen" do
    assert FailureClass.values() == [
             :policy_denied,
             :route_unresolved,
             :placement_unavailable,
             :launch_failed,
             :transport_failed,
             :protocol_framing_failed,
             :semantic_runtime_failed,
             :approval_expired,
             :lease_expired,
             :attach_mismatch,
             :remote_disconnect,
             :cancellation,
             :timeout
           ]
  end

  test "failure metadata stays typed and reusable" do
    failure = Failure.new!(%{failure_class: "launch_failed", reason: "spawn failed"})

    assert failure.failure_class == :launch_failed
    assert failure.primary_owner == :execution_plane
    assert failure.retryable?
    assert failure.durable_truth_relevance == :durable_truth
  end
end
