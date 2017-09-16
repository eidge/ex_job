defmodule Rex.Runner do
  use GenServer

  alias Rex.QueueManager

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def init(nil), do: {:ok, nil}

  def run_async(queue_manager, queue_name) do
    {:ok, pid} = start_link()
    enqueue(pid, queue_manager, queue_name)
  end

  def run(queue_manager, queue_name) do
    {:ok, {job_module, arguments}} = QueueManager.dequeue(queue_manager, queue_name)
    apply(job_module, :perform, arguments)
  end

  def enqueue(pid, queue_manager, queue_name) do
    GenServer.cast(pid, {:run, queue_manager, queue_name})
  end

  def handle_cast({:run, queue_manager, queue_name}, state) do
    run(queue_manager, queue_name)
    {:noreply, state}
  end
end
