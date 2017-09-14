defmodule Rex.QueueManager do
  use GenServer

  alias Rex.Queue
  alias Rex.QueueManager.Dispatcher

  def start_link(args \\ [], opts \\ [name: __MODULE__]) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init(args) do
    {:ok, initial_state(args)}
  end

  defp initial_state(args) do
    dispatcher = Keyword.get(args, :dispatcher, Dispatcher)
    %{queues: Map.new, dispatcher: dispatcher}
  end

  def enqueue(name \\ __MODULE__, queue_name, value) do
    GenServer.call(name, {:enqueue, queue_name, value})
  end

  def dequeue(name \\ __MODULE__, queue_name) do
    GenServer.call(name, {:dequeue, queue_name})
  end

  def queues(name \\ __MODULE__) do
    GenServer.call(name, :queues)
  end

  def handle_call({:enqueue, queue_name, value}, _from, state) do
    {queue, state} = get_or_create_queue(state, queue_name)
    {:ok, queue} = Queue.enqueue(queue, value)
    new_state = put_in(state, [:queues, queue_name], queue)
    dispatch(new_state, queue_name)
    {:reply, :ok, new_state}
  end

  def handle_call({:dequeue, queue_name}, _from, state) do
    queue = Map.get(state.queues, queue_name, Queue.new)
    case Queue.dequeue(queue) do
      {:ok, queue, result} ->
        new_state = put_in(state, [:queues, queue_name], queue)
        {:reply, {:ok, result}, new_state}
      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  def handle_call(:queues, _from, state) do
    {:reply, {:ok, state.queues}, state}
  end

  defp get_or_create_queue(state, queue_name) do
    queue = Map.get(state.queues, queue_name)
    if queue do
      {queue, state}
    else
      queue = Queue.new
      new_state = put_in(state, [:queues, queue_name], queue)
      {queue, new_state}
    end
  end

  defp dispatch(state, queue_name) do
    queue_manager = self()
    state.dispatcher.dispatch(queue_manager, queue_name)
  end
end
