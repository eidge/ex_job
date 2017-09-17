defmodule Rex.Dispatcher do
  use GenServer

  alias Rex.Runner

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(nil), do: {:ok, nil}

  def dispatch(queue_manager, queue_name) do
    :ok = GenServer.cast(__MODULE__, {:dispatch, queue_manager, queue_name})
  end

  def handle_cast({:dispatch, queue_manager, queue_name}, state) do
    Runner.run_async(queue_manager, queue_name)
    {:noreply, state}
  end
end
