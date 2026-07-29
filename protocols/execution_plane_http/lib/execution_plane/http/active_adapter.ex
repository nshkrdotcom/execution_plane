defmodule ExecutionPlane.HTTP.ActiveAdapter do
  @moduledoc false

  alias ExecutionPlane.HTTP.ActiveSession

  def start(request, owner, opts), do: ActiveSession.start(request, owner, opts)
  def send_input(session, input), do: ActiveSession.send_input(session, input)
  def end_input(session), do: ActiveSession.end_input(session)
  def cancel(session, reason), do: ActiveSession.cancel(session, reason)

  def event(_session, {:execution_plane_http_active, event}), do: {:ok, event}
  def event(_session, _message), do: :ignore
end
