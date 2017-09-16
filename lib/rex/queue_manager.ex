defmodule Rex.QueueManager do
  use GenServer

  alias Rex.Queue
  alias Rex.QueueManager.{Dispatcher, GroupDispatcher}

  def start_link(args \\ [], opts \\ [name: __MODULE__]) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init(args) do
    {:ok, initial_state(args)}
  end

  defp initial_state(_args) do
    %{queues: Map.new}
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

  def handle_call({:enqueue, job_module, args}, _from, state) do
    # This needs to be moved elsewhere
    group_by = apply(job_module, :group_by, args)
    queue_name = "#{job_module}#{group_by}"
    dispatcher =
      if group_by do
        GroupDispatcher
      else
        Dispatcher
      end

    {queue, state} = get_or_build_queue(state, queue_name)
    {:ok, queue} = Queue.enqueue(queue, {job_module, args})
    state = put_in(state, [:queues, queue_name], queue)
    dispatch(dispatcher, queue_name)
    {:reply, :ok, state}
  end

  def handle_call({:dequeue, queue_name}, _from, state) do
    queue_name = to_string(queue_name)
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

  defp dispatch(dispatcher, queue_name) do
    queue_manager = self()
    dispatcher.dispatch(queue_manager, queue_name)
  end
end
