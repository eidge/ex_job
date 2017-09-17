defmodule Rex.GroupDispatcher do
  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(nil), do: {:ok, nil}

  def dispatch(queue_manager, queue_name) do
    :ok = GenServer.cast(__MODULE__, {:dispatch, queue_manager, queue_name})
  end

  def handle_cast({:dispatch, queue_manager, queue_name}, state) do
    {:ok, pid} = worker_for(queue_name)
    Rex.Runner.enqueue(pid, queue_manager, queue_name)
    {:noreply, state}
  end

  defp worker_for(queue_name) do
    queue_name = String.to_atom(queue_name) # Get rid of this, use a proper registry
    case Rex.Runner.start_link(name: queue_name) do
      {:ok, _pid} = ok -> ok
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end
end
