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
    %{
      queues: %{pending: Map.new, working: Map.new}
    }
  end

  def enqueue(name \\ __MODULE__, job = %Rex.Job{}) do
    GenServer.call(name, {:enqueue, job})
  end

  def dequeue(name \\ __MODULE__, queue_name) do
    GenServer.call(name, {:dequeue, queue_name})
  end

  def notify_success(name \\ __MODULE__, job = %Rex.Job{}) do
    GenServer.call(name, {:notify_success, job})
  end

  def info(name \\ __MODULE__) do
    {:ok, queues} = queues(name)
    %{
      pending: job_count(queues.pending),
      processed: 0,
      working: job_count(queues.working),
      failed: 0,
      queues: queue_count(queues.pending),
    }
  end

  defp queues(name) do
    GenServer.call(name, :queues)
  end

  defp job_count(queues) do
    Enum.reduce(queues, 0, fn {_, q}, total ->
      Queue.size(q) + total
    end)
  end

  defp queue_count(queues) do
    Enum.count(queues)
  end

  def handle_call({:enqueue, job}, _from, state) do
    state = enqueue_in(state, :pending, job)
    {:reply, :ok, state}
  end

  def handle_call({:dequeue, queue_name}, _from, state) do
    queue_name = to_string(queue_name)
    queue = Map.get(state.queues.pending, queue_name, Queue.new)
    case Queue.dequeue(queue) do
      {:ok, queue, job} ->
        new_state = put_in(state, [:queues, :pending, queue_name], queue)
        new_state = enqueue_in(new_state, :working, job)
        {:reply, {:ok, job}, new_state}
      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:notify_success, _job}, _from, state) do
    state.queues.pending
    {:reply, :ok, state}
  end

  def handle_call(:queues, _from, state) do
    {:reply, {:ok, state.queues}, state}
  end

  defp enqueue_in(state, job_status, job) do
    pending_queues = state.queues
    |> Map.fetch!(job_status)
    |> get_or_build_queue(job.queue_name)
    |> push_queue(job)
    put_in(state, [:queues, job_status], pending_queues)
  end

  defp get_or_build_queue(queues, queue_name) do
    queue = Map.get(queues, queue_name, Queue.new)
    Map.put(queues, queue_name, queue)
  end

  defp push_queue(queues, job) do
    {:ok, queue} = queues
    |> Map.fetch!(job.queue_name)
    |> Queue.enqueue(job)
    Map.put(queues, job.queue_name, queue)
  end
end
