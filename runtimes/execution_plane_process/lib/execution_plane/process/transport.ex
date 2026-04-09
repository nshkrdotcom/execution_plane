defmodule ExecutionPlane.Process.Transport do
  @moduledoc """
  Execution Plane-owned long-lived process transport seam.

  Family kits consume this module instead of binding directly to the upstream
  transport package. The current implementation maps onto the upstream runtime
  while Wave 6 converges ownership onto the Execution Plane surface.
  """

  alias ExternalRuntimeTransport.Transport, as: RuntimeTransport

  @behaviour RuntimeTransport

  defdelegate start(opts), to: RuntimeTransport
  defdelegate start_link(opts), to: RuntimeTransport
  defdelegate run(command, opts), to: RuntimeTransport
  defdelegate send(transport, message), to: RuntimeTransport
  defdelegate subscribe(transport, pid), to: RuntimeTransport
  defdelegate subscribe(transport, pid, tag), to: RuntimeTransport
  defdelegate unsubscribe(transport, pid), to: RuntimeTransport
  defdelegate close(transport), to: RuntimeTransport
  defdelegate force_close(transport), to: RuntimeTransport
  defdelegate interrupt(transport), to: RuntimeTransport
  defdelegate status(transport), to: RuntimeTransport
  defdelegate end_input(transport), to: RuntimeTransport
  defdelegate stderr(transport), to: RuntimeTransport
  defdelegate info(transport), to: RuntimeTransport
  defdelegate extract_event(message), to: RuntimeTransport
  defdelegate extract_event(message, ref), to: RuntimeTransport
  defdelegate delivery_info(transport), to: RuntimeTransport
end
