defmodule ExecutionPlane.NodeTest.FakeLane do
  @moduledoc false

  @behaviour ExecutionPlane.Lane.Adapter

  alias ExecutionPlane.ExecutionEvent
  alias ExecutionPlane.ExecutionRequest
  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.Lane.Capabilities

  def lane_id, do: :process

  def capabilities do
    Capabilities.new!(
      lane_id: "process",
      protocols: ["process"],
      surfaces: ["local_subprocess"],
      supports_execute: true,
      supports_stream: true
    )
  end

  def validate(%ExecutionRequest{lane_id: "process"}), do: :ok

  def execute(request, _opts) do
    {:ok,
     ExecutionResult.new!(
       execution_ref: request.execution_ref,
       status: "succeeded",
       output: %{"ok" => true},
       provenance: request.provenance
     )}
  end

  def stream(request, _opts) do
    {:ok,
     [
       ExecutionEvent.new!(
         execution_ref: request.execution_ref,
         event_type: "fake.chunk",
         payload: %{"ok" => true}
       )
     ]}
  end
end

defmodule ExecutionPlane.NodeTest.FakeHttpLane do
  @moduledoc false

  @behaviour ExecutionPlane.Lane.Adapter

  alias ExecutionPlane.Admission.Rejection
  alias ExecutionPlane.ExecutionRequest
  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.Lane.Capabilities

  def lane_id, do: :http

  def capabilities do
    Capabilities.new!(
      lane_id: "http",
      protocols: ["http"],
      surfaces: ["remote_http"],
      supports_execute: true,
      supports_stream: false
    )
  end

  def validate(%ExecutionRequest{lane_id: "http"}), do: :ok

  def execute(request, _opts) do
    {:ok,
     ExecutionResult.new!(
       execution_ref: request.execution_ref,
       status: "succeeded",
       output: %{"http" => "ok"},
       provenance: request.provenance
     )}
  end

  def stream(_request, _opts), do: {:error, Rejection.new(:not_supported, "stream unsupported")}
end

defmodule ExecutionPlane.NodeTest.AuthorityVerifier do
  @moduledoc false

  @behaviour ExecutionPlane.Authority.Verifier

  alias ExecutionPlane.Admission.Rejection
  alias ExecutionPlane.Authority.Ref

  def verifier_id, do: "test-authority"

  def verify(%Ref{ref: "allow"}, _opts), do: {:ok, %{"sub" => "test"}}

  def verify(_ref, _opts) do
    {:error, Rejection.new(:authority_rejected, "authority rejected")}
  end
end

defmodule ExecutionPlane.NodeTest.TargetVerifier do
  @moduledoc false

  @behaviour ExecutionPlane.Target.Verifier

  alias ExecutionPlane.Admission.Rejection
  alias ExecutionPlane.Target.Attestation
  alias ExecutionPlane.Target.Descriptor

  def verifier_id, do: "test-target-verifier"
  def attestation_types, do: ["stub"]
  def capability_classes, do: ["local-erlexec-weak", "http-stub"]

  def handles?(attestation) do
    attestation = Attestation.new!(attestation)
    attestation.attestation_type == "stub"
  end

  def verify(attestation, _opts) do
    attestation = Attestation.new!(attestation)

    if attestation.evidence["signature"] == "valid" do
      {:ok,
       Descriptor.new!(
         target_id: Map.get(attestation.evidence, "target_id", "target-1"),
         lane_id: Map.get(attestation.evidence, "lane_id", "process"),
         attested_capability_classes:
           Map.get(attestation.evidence, "classes", ["local-erlexec-weak"]),
         verifier_id: verifier_id(),
         attestation_id: attestation.attestation_id,
         signature: "valid"
       )}
    else
      {:error,
       Rejection.new(
         :target_attestation_unverifiable,
         "invalid target attestation"
       )}
    end
  end
end

defmodule ExecutionPlane.NodeTest.Sink do
  @moduledoc false

  @behaviour ExecutionPlane.Evidence.Sink

  def sink_id, do: "test-sink"

  def emit(evidence, _opts) do
    if pid = Process.whereis(:execution_plane_node_test_sink) do
      send(pid, {:evidence, evidence.evidence_type})
      send(pid, {:evidence_record, evidence})
    end

    :ok
  end

  def flush(_opts), do: :ok
end

defmodule ExecutionPlane.NodeTest.RemoteRuntimeClient do
  @moduledoc false

  @behaviour ExecutionPlane.Runtime.Client

  alias ExecutionPlane.Node.LocalClient

  def describe(opts), do: LocalClient.describe(opts)
  def admit(request, opts), do: LocalClient.admit(request, opts)
  def execute(request, opts), do: LocalClient.execute(request, opts)
  def stream(request, opts), do: LocalClient.stream(request, opts)
  def cancel(execution_ref, opts), do: LocalClient.cancel(execution_ref, opts)
end

defmodule ExecutionPlane.NodeTest.JsonRpcWebSocketTargetClient do
  @moduledoc false

  @behaviour ExecutionPlane.Target.Client

  alias ExecutionPlane.ExecutionRequest
  alias ExecutionPlane.Node.TargetClient.Adapter

  def describe(opts), do: Adapter.describe(opts)

  def execute(%ExecutionRequest{} = request, opts) do
    frame = target_protocol_frame(request, "execution.execute")
    notify(frame)

    Adapter.execute(request, Keyword.put(opts, :target_protocol_frame, frame))
  end

  def stream(%ExecutionRequest{} = request, opts) do
    frame = target_protocol_frame(request, "execution.stream")
    notify(frame)

    Adapter.stream(request, Keyword.put(opts, :target_protocol_frame, frame))
  end

  def cancel(execution_ref, opts), do: Adapter.cancel(execution_ref, opts)

  defp target_protocol_frame(%ExecutionRequest{} = request, method) do
    %{
      "transport" => "jsonrpc_over_websocket",
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => ExecutionRequest.dump(request)
    }
  end

  defp notify(frame) do
    if pid = Process.whereis(:execution_plane_node_test_sink) do
      send(pid, {:target_protocol_frame, frame})
    end
  end
end
