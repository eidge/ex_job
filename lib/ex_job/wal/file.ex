defmodule ExJob.WAL.File do
  @moduledoc false

  require Logger

  defstruct [:file]

  def open(path) when is_binary(path), do: String.to_charlist(path) |> open
  def open(path) do
    Logger.info("Opening WAL file for: #{path}")
    case :disk_log.open(file: path, name: path) do
      {:ok, file} -> {:ok, %__MODULE__{file: file}}
      {:repaired, file, {:recovered, _}, {:badbytes, 0}} -> {:ok, %__MODULE__{file: file}}
      error -> error
    end
  end

  def close(%__MODULE__{file: file}) do
    :disk_log.close(file)
  end

  def append(%__MODULE__{file: file}, event) do
    :disk_log.log(file, event)
  end

  def read(%__MODULE__{file: file}) do
    Logger.info("Reading WAL file: #{file}")
    do_read(file, :start)
  end

  defp do_read(file, continuation, events \\ [])
  defp do_read(file, :eof, events) do
    Logger.info("Read #{Enum.count(events)} events for: #{file}")
    {:ok, events}
  end
  defp do_read(file, continuation, events) do
    case :disk_log.chunk(file, continuation) do
      {:error, reason} -> {:error, reason}
      :eof -> do_read(file, :eof, events)
      {continuation, new_events} -> do_read(file, continuation, events ++ new_events)
      {_, _, _bad_bytes} -> {:error, :corrupted_file}
    end
  end
end
