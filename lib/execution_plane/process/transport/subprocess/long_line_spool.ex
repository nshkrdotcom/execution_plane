defmodule ExecutionPlane.Process.Transport.Subprocess.LongLineSpool do
  @moduledoc false

  alias ExecutionPlane.Process.Transport.Subprocess.Framing

  @telemetry_prefix [
    :execution_plane,
    :process,
    :transport,
    :subprocess,
    :long_line_spool
  ]

  defmodule FileOps do
    @moduledoc false

    def tmp_dir!, do: System.tmp_dir!()
    def open(path, modes), do: File.open(path, modes)
    def write(io, chunk), do: :file.write(io, chunk)
    def close(io), do: File.close(io)
    def read(path), do: File.read(path)
    def rm(path), do: File.rm(path)
  end

  defstruct path: nil,
            io: nil,
            bytes: 0,
            chunk_count: 0,
            preview: "",
            pending_cr?: false,
            file: FileOps,
            telemetry_metadata: %{}

  @doc false
  def telemetry_events do
    [
      telemetry_event(:ceiling_exceeded),
      telemetry_event(:write_failure),
      telemetry_event(:read_failure),
      telemetry_event(:delete_failure),
      telemetry_event(:cleanup)
    ]
  end

  @doc false
  def telemetry_event(name) when is_atom(name), do: @telemetry_prefix ++ [name]

  @doc false
  def open(opts \\ []) when is_list(opts) do
    file = Keyword.get(opts, :file, FileOps)

    path =
      Keyword.get_lazy(opts, :path, fn ->
        Path.join(file.tmp_dir!(), "execution_plane_process_long_line_#{unique_id()}.tmp")
      end)

    case file.open(path, [:write, :binary]) do
      {:ok, io} ->
        {:ok,
         %__MODULE__{
           path: path,
           io: io,
           file: file,
           telemetry_metadata: %{path: path}
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  def write(%__MODULE__{} = spool, "", _chunk_bytes, _max_recoverable_bytes), do: {:ok, spool}

  def write(%__MODULE__{} = spool, data, chunk_bytes, max_recoverable_bytes)
      when is_binary(data) and is_integer(chunk_bytes) and chunk_bytes > 0 and
             is_integer(max_recoverable_bytes) and max_recoverable_bytes > 0 do
    do_write(spool, data, chunk_bytes, max_recoverable_bytes)
  end

  @doc false
  def finalize(%__MODULE__{} = spool) do
    spool = close_spool(spool)

    case spool.file.read(spool.path) do
      {:ok, line} ->
        _ = delete_spool(spool)
        {:ok, line}

      {:error, reason} ->
        _ = delete_spool(spool)
        emit(:read_failure, spool, %{reason: reason})
        {:error, {:spool_read_failed, reason, spool}}
    end
  rescue
    error ->
      spool = close_spool(spool)
      _ = delete_spool(spool)
      emit(:read_failure, spool, %{reason: error})
      {:error, {:spool_read_failed, error, spool}}
  end

  @doc false
  def cleanup(nil), do: {:ok, %{close: :ok, delete: :ok}}

  def cleanup(%__MODULE__{} = spool) do
    close_result = close_result(spool)
    spool = %{spool | io: nil}
    delete_result = delete_spool(spool)
    cleanup = %{close: close_result, delete: delete_result}
    emit(:cleanup, spool, cleanup)
    {:ok, cleanup}
  end

  @doc false
  def context(nil), do: %{bytes_preserved: 0, chunk_count: 0}

  def context(%__MODULE__{} = spool) do
    %{bytes_preserved: spool.bytes, chunk_count: spool.chunk_count}
  end

  defp do_write(%__MODULE__{} = spool, "", _chunk_bytes, _max_recoverable_bytes),
    do: {:ok, spool}

  defp do_write(%__MODULE__{} = spool, data, chunk_bytes, max_recoverable_bytes) do
    size = min(byte_size(data), chunk_bytes)
    chunk = binary_part(data, 0, size)
    rest = binary_part(data, size, byte_size(data) - size)
    next_size = spool.bytes + byte_size(chunk)

    if next_size > max_recoverable_bytes do
      emit(:ceiling_exceeded, spool, %{actual_size: next_size, max_size: max_recoverable_bytes})
      {:error, {:recoverable_ceiling_exceeded, next_size, spool}}
    else
      write_chunk(spool, chunk, rest, chunk_bytes, max_recoverable_bytes, next_size)
    end
  end

  defp write_chunk(spool, chunk, rest, chunk_bytes, max_recoverable_bytes, next_size) do
    case spool.file.write(spool.io, chunk) do
      :ok ->
        spool = %{
          spool
          | bytes: next_size,
            chunk_count: spool.chunk_count + 1,
            preview: Framing.extend_preview(spool.preview, chunk)
        }

        do_write(spool, rest, chunk_bytes, max_recoverable_bytes)

      {:error, reason} ->
        emit(:write_failure, spool, %{reason: reason})
        {:error, {:spool_write_failed, reason, spool}}
    end
  end

  defp close_spool(%__MODULE__{} = spool) do
    _ = close_result(spool)
    %{spool | io: nil}
  end

  defp close_result(%__MODULE__{io: nil}), do: :ok

  defp close_result(%__MODULE__{} = spool) do
    spool.file.close(spool.io)
  rescue
    error -> {:error, error}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp delete_spool(%__MODULE__{} = spool) do
    case spool.file.rm(spool.path) do
      :ok ->
        :ok

      {:error, reason} = error ->
        emit(:delete_failure, spool, %{reason: reason})
        error
    end
  rescue
    error ->
      emit(:delete_failure, spool, %{reason: error})
      {:error, error}
  catch
    kind, reason ->
      failure = {kind, reason}
      emit(:delete_failure, spool, %{reason: failure})
      {:error, failure}
  end

  defp emit(event_name, %__MODULE__{} = spool, metadata) when is_atom(event_name) do
    :telemetry.execute(
      telemetry_event(event_name),
      %{bytes: spool.bytes, chunk_count: spool.chunk_count},
      Map.merge(spool.telemetry_metadata, metadata)
    )
  end

  defp unique_id, do: System.unique_integer([:positive, :monotonic])
end
