defmodule ExecutionPlane.Process.Transport.SubprocessLongLineSpoolTest.MemoryFile do
  @moduledoc false

  def tmp_dir!, do: System.tmp_dir!()
  def open(_path, _modes), do: {:ok, :memory_io}
  def write(:memory_io, _chunk), do: :ok
  def close(:memory_io), do: :ok
  def read(_path), do: {:ok, "restored-line"}
  def rm(_path), do: :ok
end

defmodule ExecutionPlane.Process.Transport.SubprocessLongLineSpoolTest.WriteFailFile do
  @moduledoc false

  def tmp_dir!, do: System.tmp_dir!()
  def open(_path, _modes), do: {:ok, :write_fail_io}
  def write(:write_fail_io, _chunk), do: {:error, :enospc}
  def close(:write_fail_io), do: :ok
  def read(_path), do: {:ok, ""}
  def rm(_path), do: :ok
end

defmodule ExecutionPlane.Process.Transport.SubprocessLongLineSpoolTest.ReadFailFile do
  @moduledoc false

  def tmp_dir!, do: System.tmp_dir!()
  def open(_path, _modes), do: {:ok, :read_fail_io}
  def write(:read_fail_io, _chunk), do: :ok
  def close(:read_fail_io), do: :ok
  def read(_path), do: {:error, :enoent}
  def rm(_path), do: :ok
end

defmodule ExecutionPlane.Process.Transport.SubprocessLongLineSpoolTest.DeleteFailFile do
  @moduledoc false

  def tmp_dir!, do: System.tmp_dir!()
  def open(_path, _modes), do: {:ok, :delete_fail_io}
  def write(:delete_fail_io, _chunk), do: :ok
  def close(:delete_fail_io), do: :ok
  def read(_path), do: {:ok, "line-before-delete-failure"}
  def rm(_path), do: {:error, :eperm}
end

defmodule ExecutionPlane.Process.Transport.SubprocessLongLineSpoolTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Process.Transport.Subprocess.LongLineSpool
  alias ExecutionPlane.Process.Transport.SubprocessLongLineSpoolTest.DeleteFailFile
  alias ExecutionPlane.Process.Transport.SubprocessLongLineSpoolTest.MemoryFile
  alias ExecutionPlane.Process.Transport.SubprocessLongLineSpoolTest.ReadFailFile
  alias ExecutionPlane.Process.Transport.SubprocessLongLineSpoolTest.WriteFailFile

  setup do
    handler_id = {__MODULE__, self(), make_ref()}

    :telemetry.attach_many(
      handler_id,
      LongLineSpool.telemetry_events(),
      &__MODULE__.handle_spool_telemetry/4,
      self()
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  test "writes chunks and reports recoverable ceiling failures without extra writes" do
    assert {:ok, spool} = LongLineSpool.open(file: MemoryFile)

    assert {:error, {:recoverable_ceiling_exceeded, 9, spool}} =
             LongLineSpool.write(spool, "abcdefghi", 4, 8)

    assert spool.bytes == 8
    assert spool.chunk_count == 2
    assert spool.preview == "abcdefgh"

    assert_receive {:spool_telemetry, event, measurements, metadata}
    assert event == LongLineSpool.telemetry_event(:ceiling_exceeded)
    assert measurements.bytes == 8
    assert metadata.actual_size == 9
  end

  test "reports write failures with spool context" do
    assert {:ok, spool} = LongLineSpool.open(file: WriteFailFile)

    assert {:error, {:spool_write_failed, :enospc, failed_spool}} =
             LongLineSpool.write(spool, "abcd", 4, 8)

    assert failed_spool.bytes == 0
    assert failed_spool.chunk_count == 0

    assert_receive {:spool_telemetry, event, _measurements, metadata}
    assert event == LongLineSpool.telemetry_event(:write_failure)
    assert metadata.reason == :enospc
  end

  test "reports read failures during finalize" do
    assert {:ok, spool} = LongLineSpool.open(file: ReadFailFile)
    assert {:ok, spool} = LongLineSpool.write(spool, "abcd", 4, 8)

    assert {:error, {:spool_read_failed, :enoent, failed_spool}} =
             LongLineSpool.finalize(spool)

    assert failed_spool.bytes == 4

    assert_receive {:spool_telemetry, event, _measurements, metadata}
    assert event == LongLineSpool.telemetry_event(:read_failure)
    assert metadata.reason == :enoent
  end

  test "delete failures are emitted but do not discard recovered line" do
    assert {:ok, spool} = LongLineSpool.open(file: DeleteFailFile)
    assert {:ok, spool} = LongLineSpool.write(spool, "abcd", 4, 8)

    assert {:ok, "line-before-delete-failure"} = LongLineSpool.finalize(spool)

    assert_receive {:spool_telemetry, event, _measurements, metadata}
    assert event == LongLineSpool.telemetry_event(:delete_failure)
    assert metadata.reason == :eperm
  end

  test "cleanup closes and removes an owned spool file" do
    assert {:ok, spool} = LongLineSpool.open()
    assert {:ok, spool} = LongLineSpool.write(spool, "abcdefgh", 4, 16)
    assert File.exists?(spool.path)

    assert {:ok, cleanup} = LongLineSpool.cleanup(spool)
    assert cleanup.close == :ok
    assert cleanup.delete == :ok
    refute File.exists?(spool.path)

    assert_receive {:spool_telemetry, event, measurements, metadata}
    assert event == LongLineSpool.telemetry_event(:cleanup)
    assert measurements.bytes == 8
    assert metadata.path == spool.path
  end

  def handle_spool_telemetry(event, measurements, metadata, owner) do
    send(owner, {:spool_telemetry, event, measurements, metadata})
  end
end
