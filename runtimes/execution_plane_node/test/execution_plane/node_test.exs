defmodule ExecutionPlane.NodeTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Admission.Decision
  alias ExecutionPlane.Admission.Rejection
  alias ExecutionPlane.Admission.Request
  alias ExecutionPlane.Authority.Ref
  alias ExecutionPlane.Evidence
  alias ExecutionPlane.ExecutionEvent
  alias ExecutionPlane.ExecutionRef
  alias ExecutionPlane.ExecutionRequest
  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.Node.LocalClient
  alias ExecutionPlane.NodeTest.{JsonRpcWebSocketTargetClient, RemoteRuntimeClient}
  alias ExecutionPlane.Runtime.NodeDescriptor
  alias ExecutionPlane.Sandbox.AcceptableAttestation
  alias ExecutionPlane.Sandbox.Profile
  alias ExecutionPlane.Target.Attestation
  alias ExecutionPlane.Target.Descriptor

  setup do
    name = :"node_#{System.unique_integer([:positive])}"
    start_supervised!({ExecutionPlane.Node.Server, name: name, node_id: Atom.to_string(name)})
    Process.register(self(), :execution_plane_node_test_sink)

    on_exit(fn ->
      if Process.whereis(:execution_plane_node_test_sink) do
        Process.unregister(:execution_plane_node_test_sink)
      end
    end)

    {:ok, server: name}
  end

  test "rejects governed traffic before registration completes", %{server: server} do
    ExecutionPlane.Node.register_lane(ExecutionPlane.NodeTest.FakeLane, server: server)

    assert {:error, rejection} =
             LocalClient.admit(governed_request(), server: server)

    assert rejection.reason == "registration_incomplete"
  end

  test "rejects governed traffic without authority verifier", %{server: server} do
    register_runtime_without_authority(server)
    ExecutionPlane.Node.complete_registration(server: server)

    assert {:error, rejection} =
             LocalClient.admit(governed_request(), server: server)

    assert rejection.reason == "authority_verifier_missing"
  end

  test "target enters routing table only after verifier-valid attestation", %{server: server} do
    ExecutionPlane.Node.register_target_verifier(ExecutionPlane.NodeTest.TargetVerifier,
      server: server
    )

    invalid =
      Attestation.new!(
        attestation_type: "stub",
        evidence: %{"signature" => "not-valid"}
      )

    assert {:error, rejection} =
             ExecutionPlane.Node.connect_target(
               invalid,
               ExecutionPlane.Node.TargetClient.Adapter,
               server: server
             )

    assert rejection.reason == "target_attestation_unverifiable"

    valid = Attestation.new!(attestation_type: "stub", evidence: %{"signature" => "valid"})

    assert {:ok, descriptor} =
             ExecutionPlane.Node.connect_target(
               valid,
               ExecutionPlane.Node.TargetClient.Adapter,
               server: server
             )

    assert descriptor.attested_capability_classes == ["local-erlexec-weak"]
  end

  test "rejects target claims with no matching verifier and never routes them", %{server: server} do
    ExecutionPlane.Node.register_target_verifier(ExecutionPlane.NodeTest.TargetVerifier,
      server: server
    )

    attestation =
      Attestation.new!(
        attestation_type: "unsigned-strong-claim",
        claimed_capability_classes: ["spiffe://prod/microvm-strict@v1"],
        evidence: %{"signature" => "valid"}
      )

    assert {:error, rejection} =
             ExecutionPlane.Node.connect_target(
               attestation,
               ExecutionPlane.Node.TargetClient.Adapter,
               server: server
             )

    assert rejection.reason == "target_attestation_unverifiable"

    assert {:ok, descriptor} = LocalClient.describe(server: server)
    assert descriptor.verified_targets == []
  end

  test "rejects strong isolation claims without verifier-backed evidence", %{server: server} do
    ExecutionPlane.Node.register_target_verifier(ExecutionPlane.NodeTest.TargetVerifier,
      server: server
    )

    attestation =
      Attestation.new!(
        attestation_type: "stub",
        claimed_capability_classes: ["spiffe://prod/microvm-strict@v1"],
        evidence: %{
          "signature" => "not-valid",
          "classes" => ["spiffe://prod/microvm-strict@v1"]
        }
      )

    assert {:error, rejection} =
             ExecutionPlane.Node.connect_target(
               attestation,
               ExecutionPlane.Node.TargetClient.Adapter,
               server: server
             )

    assert rejection.reason == "target_attestation_unverifiable"

    assert {:ok, descriptor} = LocalClient.describe(server: server)
    assert descriptor.verified_targets == []
  end

  test "admits and executes against matching attested target", %{server: server} do
    register_runtime(server)

    assert {:ok, result} = LocalClient.execute(governed_request(), server: server)
    assert result.status == "succeeded"

    assert_receive {:evidence, "admission.accepted"}
  end

  test "governed HTTP request executes through runtime client to attested HTTP target", %{
    server: server
  } do
    register_http_runtime(server)

    request =
      governed_request(
        lane_id: "http",
        payload: %{"method" => "GET", "url" => "https://example.test"},
        acceptable_attestation: AcceptableAttestation.new!(classes: ["http-stub"])
      )

    assert {:ok, result} = LocalClient.execute(request, server: server)
    assert result.status == "succeeded"
    assert result.output == %{"http" => "ok"}
  end

  test "registration-complete node with zero verified targets rejects governed traffic", %{
    server: server
  } do
    register_runtime_without_target(server)

    assert {:error, result} = LocalClient.execute(governed_request(), server: server)
    assert result.status == "rejected"
    assert result.error["reason"] == "no_satisfying_attested_target"

    assert {:ok, descriptor} = LocalClient.describe(server: server)
    assert descriptor.verified_targets == []
  end

  test "remote runtime client can replace the local runtime client", %{server: server} do
    register_remote_runtime(server)

    assert {:ok, result} =
             RemoteRuntimeClient.execute(
               governed_request(),
               server: server
             )

    assert result.status == "succeeded"
  end

  test "stub remote target uses JSON-RPC over WebSocket target protocol", %{server: server} do
    register_remote_runtime(server)

    assert {:ok, result} = LocalClient.execute(governed_request(), server: server)
    assert result.status == "succeeded"

    assert_receive {:target_protocol_frame,
                    %{
                      "transport" => "jsonrpc_over_websocket",
                      "jsonrpc" => "2.0",
                      "method" => "execution.execute",
                      "params" => %{
                        "lane_id" => "process",
                        "target_descriptor" => %{
                          "target_id" => "remote-target-1",
                          "verifier_id" => "test-target-verifier"
                        }
                      }
                    }}
  end

  test "one execute dispatches to at most one attested target and does not fallback", %{
    server: server
  } do
    register_remote_runtime(server, ["remote-target-1", "remote-target-2"])

    assert {:ok, result} = LocalClient.execute(governed_request(), server: server)
    assert result.status == "succeeded"

    assert_receive {:target_protocol_frame,
                    %{
                      "method" => "execution.execute",
                      "params" => %{"target_descriptor" => %{"target_id" => target_id}}
                    }}

    assert target_id in ["remote-target-1", "remote-target-2"]
    refute_receive {:target_protocol_frame, _frame}, 50
  end

  test "rejects local process when acceptable set excludes local-erlexec-weak", %{server: server} do
    register_runtime(server)

    request =
      governed_request(
        acceptable_attestation:
          AcceptableAttestation.new!(classes: ["spiffe://prod/microvm-strict@v1"])
      )

    assert {:error, result} = LocalClient.execute(request, server: server)
    assert result.status == "rejected"
    assert result.error["reason"] == "no_satisfying_attested_target"
  end

  test "direct lower-lane-owner provenance skips governed authority", %{server: server} do
    ExecutionPlane.Node.register_lane(ExecutionPlane.NodeTest.FakeLane, server: server)

    request =
      Request.new!(
        lane_id: "process",
        payload: %{"command" => "echo"},
        provenance: ExecutionPlane.Provenance.direct_lower_lane_owner("cli_subprocess_core")
      )

    assert {:ok, decision} = LocalClient.admit(request, server: server)
    assert decision.reason == "direct lower-lane-owner execution"
  end

  test "contract version mismatch is rejected at admission", %{server: server} do
    register_runtime(server)

    assert {:error, rejection} =
             LocalClient.admit(governed_request(contract_version: 0), server: server)

    assert rejection.reason == "contract_version_mismatch"
  end

  test "evidence sink receives admission, target, execution, and cancellation context", %{
    server: server
  } do
    register_runtime(server)

    assert {:ok, result} = LocalClient.execute(governed_request(), server: server)
    assert :ok = LocalClient.cancel(result.execution_ref, server: server)

    evidence =
      collect_evidence_records([
        "admission.accepted",
        "target.selected",
        "execution.started",
        "execution.completed",
        "execution.cancelled"
      ])

    Enum.each(evidence, fn record ->
      assert record.contract_version == ExecutionPlane.ContractVersion.current()
      assert record.policy_bundle_hash == "sha256:test"
      assert record.target_id == "target-1"
      assert record.target_verifier_id == "test-target-verifier"
      assert record.attestation_class == "local-erlexec-weak"
      assert record.lane_id == "process"
      assert record.authority_verifier_id == "test-authority"
    end)
  end

  test "describe reports contract range, lanes, verifiers, targets, and authority", %{
    server: server
  } do
    register_runtime(server)

    assert {:ok, descriptor} = LocalClient.describe(server: server)
    assert descriptor.contract_version_range == %{"min" => 1, "max" => 1}
    assert [%{"lane_id" => "process"}] = descriptor.registered_lanes
    assert [%{"verifier_id" => "test-target-verifier"}] = descriptor.registered_target_verifiers
    assert [%Descriptor{}] = descriptor.verified_targets
    assert descriptor.authority_verifier == "test-authority"
  end

  test "boundary contracts JSON round trip all remote values with contract version" do
    request = governed_request()
    ref = ExecutionRef.new!()
    attestation = Attestation.new!(attestation_type: "stub", evidence: %{"signature" => "valid"})

    target =
      Descriptor.new!(
        target_id: "target-1",
        lane_id: "process",
        attested_capability_classes: ["local-erlexec-weak"],
        verifier_id: "test-target-verifier",
        signature: "valid"
      )

    decoded =
      request
      |> ExecutionPlane.Codec.encode!()
      |> ExecutionPlane.Codec.decode!(Request)

    assert decoded.contract_version == ExecutionPlane.ContractVersion.current()
    assert decoded.request_id == request.request_id
    assert decoded.acceptable_attestation.classes == ["local-erlexec-weak"]

    values = [
      ref,
      request,
      Decision.new!(request_id: request.request_id, execution_ref: ref.ref, lane_id: "process"),
      Rejection.new(:contract_version_mismatch, "mismatch"),
      attestation,
      target,
      ExecutionRequest.new!(
        execution_ref: ref.ref,
        admission_request: request,
        target_descriptor: target,
        lane_id: "process"
      ),
      ExecutionResult.new!(execution_ref: ref.ref, status: "succeeded"),
      ExecutionEvent.new!(execution_ref: ref.ref, event_type: "test.event"),
      Evidence.new!(
        evidence_type: "test.evidence",
        execution_ref: ref.ref,
        request_id: request.request_id,
        target_id: target.target_id
      ),
      NodeDescriptor.new!(node_id: "node-1", verified_targets: [target])
    ]

    Enum.each(values, fn value ->
      assert %{contract_version: 1} = ExecutionPlane.Codec.round_trip!(value)
    end)
  end

  defp register_runtime(server) do
    register_runtime_without_authority(server)

    ExecutionPlane.Node.register_authority_verifier(ExecutionPlane.NodeTest.AuthorityVerifier,
      server: server
    )

    ExecutionPlane.Node.complete_registration(server: server)
  end

  defp register_runtime_without_target(server) do
    ExecutionPlane.Node.register_lane(ExecutionPlane.NodeTest.FakeLane, server: server)

    ExecutionPlane.Node.register_target_verifier(ExecutionPlane.NodeTest.TargetVerifier,
      server: server
    )

    ExecutionPlane.Node.register_evidence_sink(ExecutionPlane.NodeTest.Sink, server: server)

    ExecutionPlane.Node.register_authority_verifier(ExecutionPlane.NodeTest.AuthorityVerifier,
      server: server
    )

    ExecutionPlane.Node.complete_registration(server: server)
  end

  defp register_remote_runtime(server, target_ids \\ ["remote-target-1"]) do
    ExecutionPlane.Node.register_lane(ExecutionPlane.NodeTest.FakeLane, server: server)

    ExecutionPlane.Node.register_target_verifier(ExecutionPlane.NodeTest.TargetVerifier,
      server: server
    )

    ExecutionPlane.Node.register_evidence_sink(ExecutionPlane.NodeTest.Sink, server: server)

    ExecutionPlane.Node.register_authority_verifier(ExecutionPlane.NodeTest.AuthorityVerifier,
      server: server
    )

    Enum.each(target_ids, fn target_id ->
      valid =
        Attestation.new!(
          attestation_type: "stub",
          evidence: %{
            "signature" => "valid",
            "target_id" => target_id,
            "lane_id" => "process",
            "classes" => ["local-erlexec-weak"]
          }
        )

      {:ok, _descriptor} =
        ExecutionPlane.Node.connect_target(
          valid,
          JsonRpcWebSocketTargetClient,
          server: server
        )
    end)

    ExecutionPlane.Node.complete_registration(server: server)
  end

  defp register_runtime_without_authority(server) do
    ExecutionPlane.Node.register_lane(ExecutionPlane.NodeTest.FakeLane, server: server)

    ExecutionPlane.Node.register_target_verifier(ExecutionPlane.NodeTest.TargetVerifier,
      server: server
    )

    ExecutionPlane.Node.register_evidence_sink(ExecutionPlane.NodeTest.Sink, server: server)

    valid = Attestation.new!(attestation_type: "stub", evidence: %{"signature" => "valid"})

    {:ok, _descriptor} =
      ExecutionPlane.Node.connect_target(
        valid,
        ExecutionPlane.Node.TargetClient.Adapter,
        server: server
      )
  end

  defp register_http_runtime(server) do
    ExecutionPlane.Node.register_lane(ExecutionPlane.NodeTest.FakeHttpLane, server: server)

    ExecutionPlane.Node.register_target_verifier(ExecutionPlane.NodeTest.TargetVerifier,
      server: server
    )

    ExecutionPlane.Node.register_evidence_sink(ExecutionPlane.NodeTest.Sink, server: server)

    ExecutionPlane.Node.register_authority_verifier(ExecutionPlane.NodeTest.AuthorityVerifier,
      server: server
    )

    valid =
      Attestation.new!(
        attestation_type: "stub",
        evidence: %{
          "signature" => "valid",
          "target_id" => "http-target-1",
          "lane_id" => "http",
          "classes" => ["http-stub"]
        }
      )

    {:ok, _descriptor} =
      ExecutionPlane.Node.connect_target(
        valid,
        ExecutionPlane.Node.TargetClient.Adapter,
        server: server
      )

    ExecutionPlane.Node.complete_registration(server: server)
  end

  defp collect_evidence_records(event_types) do
    event_types
    |> Enum.map(fn event_type ->
      assert_receive {:evidence_record, %Evidence{evidence_type: ^event_type} = evidence}
      evidence
    end)
  end

  defp governed_request(attrs \\ []) do
    Request.new!(
      Keyword.merge(
        [
          lane_id: "process",
          payload: %{"command" => "echo", "argv" => ["ok"]},
          authority_ref: Ref.new!(ref: "allow"),
          acceptable_attestation: AcceptableAttestation.new!(classes: ["local-erlexec-weak"]),
          sandbox_profile:
            Profile.new!(
              profile_ref: "sandbox://test",
              bundle_hash: "sha256:test"
            )
        ],
        attrs
      )
    )
  end
end
