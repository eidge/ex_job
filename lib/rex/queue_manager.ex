defmodule Rex.QueueManager do
  use GenServer

  alias Rex.Queue

  def start_link(args \\ [], opts \\ [name: __MODULE__]) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init(args) do
    {:ok, initial_state(args)}
  end

  defp initial_state(_args) do
    %{queues: Map.new}
  end

  def enqueue(name \\ __MODULE__, job = %Rex.Job{}) do
    GenServer.call(name, {:enqueue, job})
  end

  def dequeue(name \\ __MODULE__, queue_name) do
    GenServer.call(name, {:dequeue, queue_name})
  end

  def queues(name \\ __MODULE__) do
    GenServer.call(name, :queues)
  end

  def handle_call({:enqueue, job}, _from, state) do
    {queue, state} = get_or_build_queue(state, job.queue_name)
    {:ok, queue} = Queue.enqueue(queue, job)
    state = put_in(state, [:queues, job.queue_name], queue)
    {:reply, :ok, state}
  end

  def handle_call({:dequeue, queue_name}, _from, state) do
    queue_name = to_string(queue_name)
    queue = Map.get(state.queues, queue_name, Queue.new)
    case Queue.dequeue(queue) do
      {:ok, queue, job} ->
        new_state = put_in(state, [:queues, queue_name], queue)
        {:reply, {:ok, job}, new_state}
      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  def handle_call(:queues, _from, state) do
    {:reply, {:ok, state.queues}, state}
  end

  defp get_or_build_queue(state, queue_name) do
    queue = Map.get(state.queues, queue_name)
    if queue do
      {queue, state}
    else
      queue = Queue.new
      new_state = put_in(state, [:queues, queue_name], queue)
      {queue, new_state}
    end
  end
end
