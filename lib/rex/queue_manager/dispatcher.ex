defmodule Rex.QueueManager.Dispatcher do
  use GenServer

  alias Rex.QueueManager

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(nil), do: {:ok, nil}

  def dispatch(queue_manager, job_module) do
    :ok = GenServer.cast(__MODULE__, {:dispatch, queue_manager, job_module})
  end

  def handle_cast({:dispatch, queue_manager, job_module}, state) do
    {:ok, arguments} = QueueManager.dequeue(queue_manager, job_module)
    apply(job_module, :perform, arguments)
    {:noreply, state}
  end
end
