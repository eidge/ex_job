defmodule ExJob.WAL.InMemoryFile do
  @moduledoc """
  In memory storage for the WAL. This implementation is most useful for tests.
  """

  use GenServer

  defstruct [:pid]

  def open(_path) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, nil)
  end

  def init(nil) do
    {:ok, []}
  end

  def close(pid) do
    GenServer.stop(pid)
  end

  def append(pid, event) do
    GenServer.call(pid, {:append, event})
  end

  def read(pid) do
    GenServer.call(pid, :read)
  end

  def handle_call({:append, event}, _from, events) do
    events = [event | events]
    {:reply, :ok, events}
  end

  def handle_call(:read, _from, events) do
    ordered_events = Enum.reverse(events)
    {:reply, {:ok, ordered_events}, events}
  end
end
