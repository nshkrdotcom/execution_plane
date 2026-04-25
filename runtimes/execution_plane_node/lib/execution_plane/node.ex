defmodule ExecutionPlane.Node do
  @moduledoc """
  Public registration and local runtime-client surface for an Execution Plane node.
  """

  alias ExecutionPlane.Node.Server

  @default_server Server

  def register_lane(adapter, opts \\ []), do: Server.register_lane(server(opts), adapter, opts)

  def register_target_verifier(verifier, opts \\ []),
    do: Server.register_target_verifier(server(opts), verifier, opts)

  def register_evidence_sink(sink, opts \\ []),
    do: Server.register_evidence_sink(server(opts), sink, opts)

  def register_authority_verifier(verifier, opts \\ []),
    do: Server.register_authority_verifier(server(opts), verifier, opts)

  def complete_registration(opts \\ []), do: Server.complete_registration(server(opts), opts)

  def connect_target(attestation, target_client, opts \\ []) do
    Server.connect_target(server(opts), attestation, target_client, opts)
  end

  def describe(opts \\ []), do: Server.describe(server(opts), opts)
  def admit(request, opts \\ []), do: Server.admit(server(opts), request, opts)
  def execute(request, opts \\ []), do: Server.execute(server(opts), request, opts)
  def stream(request, opts \\ []), do: Server.stream(server(opts), request, opts)
  def cancel(execution_ref, opts \\ []), do: Server.cancel(server(opts), execution_ref, opts)

  defp server(opts), do: Keyword.get(opts, :server, @default_server)
end
