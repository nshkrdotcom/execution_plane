defmodule ExecutionPlane.Process.Transport.GuestBridge.Payload do
  @moduledoc false

  @max_stderr_buffer_size 262_144

  @doc false
  def normalize(message) when is_binary(message), do: message
  def normalize(message) when is_map(message), do: Jason.encode!(message)

  def normalize(message) when is_list(message) do
    IO.iodata_to_binary(message)
  rescue
    ArgumentError -> Jason.encode!(message)
  end

  def normalize(message), do: to_string(message)

  @doc false
  def ensure_newline(payload, :line) do
    if String.ends_with?(payload, "\n"), do: payload, else: payload <> "\n"
  end

  def ensure_newline(payload, _stdin_mode), do: payload

  @doc false
  def trim_stderr(buffer) when byte_size(buffer) <= @max_stderr_buffer_size, do: buffer

  def trim_stderr(buffer) do
    size = byte_size(buffer)
    :binary.part(buffer, size - @max_stderr_buffer_size, @max_stderr_buffer_size)
  end
end
