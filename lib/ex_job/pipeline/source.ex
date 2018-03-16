defmodule ExJob.Pipeline.Source do
  @moduledoc false

  use GenStage

  alias ExJob.{WAL, Queue}
  alias ExJob.WAL.Events

  def start_link(args \\ []) do
    job_module = Keyword.get(args, :job_module)
    opts = Keyword.get(args, :options, [])
    GenStage.start_link(__MODULE__, job_module, opts)
  end

  def init(job_module), do: {:producer, initial_state(job_module)}

  defp initial_state(job_module) do
    {:ok, queue} = WAL.read(job_module)
    %{queue: queue, demand: 0}
  end

  def enqueue(pid, job), do: GenStage.call(pid, {:enqueue, job})

  def notify_success(pid, job) do
    WAL.append(Events.JobDone.new(job, :success))
    GenStage.call(pid, {:notify, job, :success})
  end

  def notify_failure(pid, job) do
    WAL.append(Events.JobDone.new(job, :failure))
    GenStage.call(pid, {:notify, job, :failure})
  end

  def info(pid) do
    GenStage.call(pid, :info)
  end

  def handle_call({:enqueue, job}, _from, state) do
    :ok = WAL.append(Events.JobEnqueued.new(job))
    {:ok, queue} = Queue.enqueue(state.queue, job)
    state = %{state | queue: queue}
    async_emit_events()
    {:reply, :ok, [], state}
  end

  def handle_call({:notify, job, result}, _from, state) do
    {:ok, queue} = Queue.done(state.queue, job, result)
    state = %{state | queue: queue}
    async_emit_events()
    {:reply, :ok, [], state}
  end

  def handle_call(:info, _from, state) do
    info = %{
      pending: Queue.size(state.queue, :pending),
      working: Queue.size(state.queue, :working),
      processed: state.queue.processed_count,
      failed: state.queue.failed_count
    }
    {:reply, info, [], state}
  end

  def handle_demand(demand, state) do
    state = %{state | demand: state.demand + demand}
    {state, events} = emit_events(state)
    {:noreply, events, state}
  end

  defp async_emit_events, do: send(self(), :emit_events)

  def handle_info(:emit_events, state) do
    {state, events} = emit_events(state)
    {:noreply, events, state}
  end

  defp emit_events(state, events \\ [])
  defp emit_events(%{demand: 0} = state, events), do: {state, Enum.reverse(events)}
  defp emit_events(state, events) do
    case Queue.dequeue(state.queue) do
      {:ok, queue, job} ->
        :ok = WAL.append(Events.JobStarted.new(job))
        demand = state.demand - 1
        state = %{state | queue: queue, demand: demand}
        events = [job | events]
        emit_events(state, events)
      {:wait, _} -> # probably worth it to change this to {:error, :wait}
        {state, Enum.reverse(events)}
      {:error, :empty} ->
        {state, Enum.reverse(events)}
    end
  end
end
