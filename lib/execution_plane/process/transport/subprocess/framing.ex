defmodule ExecutionPlane.Process.Transport.Subprocess.Framing do
  @moduledoc false

  alias ExecutionPlane.LineFraming

  @preview_bytes 160

  @doc false
  def push_stdout(%LineFraming{} = framer, data) when is_binary(data) do
    LineFraming.push(framer, data)
  end

  @doc false
  def flush_stdout(%LineFraming{} = framer), do: LineFraming.flush(framer)

  @doc false
  def push_stderr(%LineFraming{} = framer, data) when is_binary(data) do
    LineFraming.push(framer, data)
  end

  @doc false
  def flush_stderr(%LineFraming{} = framer), do: LineFraming.flush(framer)

  @doc false
  def enqueue_lines(queue, lines) when is_list(lines) do
    Enum.reduce(lines, queue, fn line, acc -> :queue.in(line, acc) end)
  end

  @doc false
  def append_stderr_buffer(_existing, _data, max_size)
      when not is_integer(max_size) or max_size <= 0,
      do: ""

  def append_stderr_buffer(existing, data, max_size)
      when is_binary(existing) and is_binary(data) do
    combined = existing <> data
    combined_size = byte_size(combined)

    if combined_size <= max_size do
      combined
    else
      :binary.part(combined, combined_size - max_size, max_size)
    end
  end

  @doc false
  def drop_until_next_newline(data) when is_binary(data) do
    case :binary.match(data, "\n") do
      :nomatch ->
        :none

      {idx, 1} ->
        rest_start = idx + 1
        rest_size = byte_size(data) - rest_start

        rest =
          if rest_size > 0 do
            :binary.part(data, rest_start, rest_size)
          else
            ""
          end

        {:rest, rest}
    end
  end

  @doc false
  def preview(data) when is_binary(data) do
    if byte_size(data) <= @preview_bytes do
      data
    else
      :binary.part(data, 0, @preview_bytes)
    end
  end

  @doc false
  def split_long_line_data(data) when is_binary(data) do
    case find_line_boundary(data) do
      :none ->
        {payload, pending_cr?} = split_trailing_cr(data)
        {:incomplete, payload, pending_cr?}

      {:complete, payload, rest} ->
        {:complete, payload, rest}
    end
  end

  @doc false
  def extend_preview(preview, _chunk) when byte_size(preview) >= @preview_bytes, do: preview

  def extend_preview(preview, chunk) when is_binary(preview) and is_binary(chunk) do
    needed = @preview_bytes - byte_size(preview)
    preview <> binary_part(chunk, 0, min(byte_size(chunk), needed))
  end

  defp find_line_boundary(data) when is_binary(data) do
    do_find_line_boundary(data, 0)
  end

  defp do_find_line_boundary(data, index) when index >= byte_size(data), do: :none

  defp do_find_line_boundary(data, index) do
    case :binary.at(data, index) do
      ?\n ->
        prefix_end =
          if index > 0 and :binary.at(data, index - 1) == ?\r, do: index - 1, else: index

        payload = binary_part(data, 0, prefix_end)
        rest_start = index + 1
        rest = binary_part(data, rest_start, byte_size(data) - rest_start)
        {:complete, payload, rest}

      ?\r ->
        split_cr_boundary(data, index)

      _other ->
        do_find_line_boundary(data, index + 1)
    end
  end

  defp split_cr_boundary(data, index) do
    cond do
      index == byte_size(data) - 1 ->
        :none

      :binary.at(data, index + 1) == ?\n ->
        payload = binary_part(data, 0, index)
        rest_start = index + 2
        rest = binary_part(data, rest_start, byte_size(data) - rest_start)
        {:complete, payload, rest}

      true ->
        payload = binary_part(data, 0, index)
        rest_start = index + 1
        rest = binary_part(data, rest_start, byte_size(data) - rest_start)
        {:complete, payload, rest}
    end
  end

  defp split_trailing_cr(""), do: {"", false}

  defp split_trailing_cr(data) do
    size = byte_size(data)

    if size > 0 and :binary.at(data, size - 1) == ?\r do
      {binary_part(data, 0, size - 1), true}
    else
      {data, false}
    end
  end
end
