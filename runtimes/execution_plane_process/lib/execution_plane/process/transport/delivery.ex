defmodule ExecutionPlane.Process.Transport.Delivery do
  @moduledoc """
  Stable mailbox-delivery metadata for transport subscribers.

  Direct adapters can use this metadata together with
  `ExecutionPlane.Process.Transport.extract_event/1` and
  `ExecutionPlane.Process.Transport.extract_event/2` to relay transport events
  without depending on internal worker identity.
  """

  defstruct message_shape: :tagged,
            tagged_event_tag: nil,
            default_subscription_tag: :subscriber_pid

  @type t :: %__MODULE__{
          message_shape: :tagged,
          tagged_event_tag: atom(),
          default_subscription_tag: :subscriber_pid
        }

  @spec new(atom()) :: t()
  def new(tagged_event_tag) when is_atom(tagged_event_tag) do
    %__MODULE__{tagged_event_tag: tagged_event_tag}
  end
end
