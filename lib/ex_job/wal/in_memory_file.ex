defmodule ExJob.WAL.InMemoryFile do
  @moduledoc """
  In memory storage for the WAL. This implementation is most useful for tests.
  """

  use GenServer

  defstruct [:pid]

  def open(filename) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, filename)
  end

  def init(filename) do
    state = %{
      events: [],
      filename: filename,
      closed: false,
      path: filename
    }

    {:ok, state}
  end

  def path(pid) do
    GenServer.call(pid, :path)
  end

  def close(pid) do
    GenServer.call(pid, :close)
  end

  def truncate(pid) do
    GenServer.call(pid, :truncate)
  end

  def append(pid, event) do
    GenServer.call(pid, {:append, event})
  end

  def read(pid) do
    GenServer.call(pid, :read)
  end

  def read_closed(pid) do
    # used in tests to read contents after file was "closed"
    GenServer.call(pid, :read_closed)
  end

  def handle_call(:path, _from, state) do
    {:reply, state.path, state}
  end

  def handle_call(:read_closed, _from, %{closed: true} = state) do
    ordered_events = Enum.reverse(state.events)
    {:reply, {:ok, ordered_events}, state}
  end

  def handle_call(_, _, %{closed: true}), do: throw("File is closed")

  def handle_call(:close, _from, state) do
    {:reply, :ok, %{state | closed: true}}
  end

  def handle_call(:truncate, _from, state) do
    {:reply, :ok, %{state | events: []}}
  end

  def handle_call({:append, event}, _from, state) do
    events = [event | state.events]
    {:reply, :ok, %{state | events: events}}
  end

  def handle_call(:read, _from, state) do
    ordered_events = Enum.reverse(state.events)
    {:reply, {:ok, ordered_events}, state}
  end
end
