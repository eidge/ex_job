defmodule ExJob.QueueManager do
  @moduledoc false

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
    %{ queues: %{} }
  end

  def enqueue(name \\ __MODULE__, job = %ExJob.Job{}) do
    GenServer.call(name, {:enqueue, job})
  end

  def dequeue(name \\ __MODULE__, queue_name) do
    GenServer.call(name, {:dequeue, queue_name})
  end

  def notify_success(name \\ __MODULE__, job = %ExJob.Job{}) do
    GenServer.call(name, {:notify, job, :success})
  end

  def notify_failure(name \\ __MODULE__, job = %ExJob.Job{}) do
    GenServer.call(name, {:notify, job, :failure})
  end

  def info(name \\ __MODULE__) do
    GenServer.call(name, :info)
  end

  def handle_call({:enqueue, job}, _from, state) do
    {:ok, queue} = state.queues
    |> get_queue(job)
    |> Queue.enqueue(job)
    state = put_in(state, [:queues, job.queue_name], queue)
    {:reply, :ok, state}
  end

  def handle_call({:dequeue, queue_name}, _from, state) when is_binary(queue_name) do
    queue = get_queue(state.queues, %{queue_name: queue_name})
    case Queue.dequeue(queue) do
      {:ok, queue, job} ->
        new_state = put_in(state, [:queues, job.queue_name], queue)
        {:reply, {:ok, job}, new_state}
      {:wait, _} = wait ->
        {:reply, wait, state}
      {:error, _} = error ->
        {:reply, error, state}
    end
  end
  def handle_call({:dequeue, queue_name}, from, state) do
    queue_name = to_string(queue_name)
    handle_call({:dequeue, queue_name}, from, state)
  end

  def handle_call({:notify, job, result}, _from, state) do
    {:ok, queue} = state.queues
    |> get_queue(job)
    |> Queue.done(job, result)
    state = put_in(state, [:queues, job.queue_name], queue)
    {:reply, :ok, state}
  end

  def handle_call(:info, _from, state) do
    pending_count = count_queues(state.queues, &(Queue.size(&1, :pending)))
    working_count = count_queues(state.queues, &(Queue.size(&1, :working)))
    processed_count = count_queues(state.queues, &(&1.processed_count))
    failed_count = count_queues(state.queues, &(&1.failed_count))
    info = %{
      pending: pending_count,
      processed: processed_count,
      working: working_count,
      failed: failed_count,
      queues: queue_count(state.queues),
    }
    {:reply, info, state}
  end

  defp get_queue(queues, %{queue_name: queue_name, queue_module: queue}),
    do: Map.get(queues, queue_name, queue.new)
  defp get_queue(queues, %{queue_name: queue_name}),
    do: Map.get(queues, queue_name, Queue.SimpleQueue.new)

  defp count_queues(queues, fun) do
    Enum.reduce(queues, 0, fn {_, queue}, memo ->
      fun.(queue) + memo
    end)
  end

  defp queue_count(queues) do
    Enum.count(queues)
  end
end
