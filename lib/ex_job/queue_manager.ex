defmodule ExJob.QueueManager do
  defmodule NotWorkingError do
    defexception message: "Job was not found in the :working queue"
  end

  use GenServer

  alias ExJob.Queue

  def start_link(args \\ [], opts \\ [name: __MODULE__]) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init(_args) do
    {:ok, initial_state()}
  end

  defp initial_state() do
    %{
      queues: %{pending: Map.new, working: Map.new}, processed_count: 0, failed_count: 0
    }
  end

  def enqueue(name \\ __MODULE__, job = %ExJob.Job{}) do
    GenServer.call(name, {:enqueue, job})
  end

  def dequeue(name \\ __MODULE__, queue_name) do
    GenServer.call(name, {:dequeue, queue_name})
  end

  def notify_success(name \\ __MODULE__, job = %ExJob.Job{}) do
    GenServer.call(name, {:notify_success, job})
  end

  def notify_failure(name \\ __MODULE__, job = %ExJob.Job{}) do
    GenServer.call(name, {:notify_failure, job})
  end

  def info(name \\ __MODULE__) do
    GenServer.call(name, :info)
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

  def handle_call({:notify_success, job}, _from, state) do
    state = state
    |> remove_job_from_working_queue(job)
    |> increment(:processed_count)
    {:reply, :ok, state}
  end

  def handle_call({:notify_failure, job}, _from, state) do
    state = state
    |> remove_job_from_working_queue(job)
    |> increment(:failed_count)
    {:reply, :ok, state}
  end

  def handle_call(:info, _from, state) do
    queues = state.queues
    processed_count = state.processed_count
    failed_count = state.failed_count
    info = %{
      pending: job_count(queues.pending),
      processed: processed_count,
      working: job_count(queues.working),
      failed: failed_count,
      queues: queue_count(queues.pending),
    }
    {:reply, info, state}
  end

  defp job_count(queues) do
    Enum.reduce(queues, 0, fn {_, q}, total ->
      Queue.size(q) + total
    end)
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

  defp remove_job_from_working_queue(state, job) do
    list = state.queues.working
    |> Map.get(job.queue_name, Queue.new)
    |> Queue.to_list

    job_index = Enum.find_index(list, fn j -> j.ref == job.ref end)
    unless job_index, do: raise(NotWorkingError)

    queue = list
    |> List.delete_at(job_index)
    |> Queue.from_list

    put_in(state, [:queues, :working, job.queue_name], queue)
  end

  defp increment(state, count_type) do
    Map.update!(state, count_type, &(&1 + 1))
  end
end
