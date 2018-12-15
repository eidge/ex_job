defmodule ExJob.Pipeline.Source do
  @moduledoc false

  use GenStage

  alias ExJob.{WAL, Queue}
  alias ExJob.WAL.Events

  def start_link(args \\ []) do
    job_module = Keyword.get(args, :job_module)
    wal = Keyword.get(args, :wal)
    opts = Keyword.get(args, :options, [])
    GenStage.start_link(__MODULE__, {job_module, wal}, opts)
  end

  def init({job_module, wal}), do: {:producer, initial_state(job_module, wal)}

  defp initial_state(job_module, wal) do
    {:ok, queue, wal_size} = WAL.read(wal, job_module)
    snapshot_period = Application.get_env(:ex_job, :snapshot_period, 10_000)

    %{
      queue: queue,
      wal: wal,
      demand: 0,
      snapshot_period: snapshot_period,
      last_snapshot: wal_size,
      job_module: job_module
    }
  end

  def enqueue(pid, job), do: GenStage.call(pid, {:enqueue, job})

  def notify_success(pid, job) do
    GenStage.call(pid, {:notify, job, :success})
  end

  def notify_failure(pid, job) do
    GenStage.call(pid, {:notify, job, :failure})
  end

  def info(pid) do
    GenStage.call(pid, :info)
  end

  def handle_call({:enqueue, job}, _from, state) do
    :ok = WAL.append(state.wal, Events.JobEnqueued.new(job))
    {:ok, queue} = Queue.enqueue(state.queue, job)
    state = %{state | queue: queue}
    state = maybe_create_snapshot(state)
    async_emit_events()
    {:reply, :ok, [], state}
  end

  def handle_call({:notify, job, result}, _from, state) do
    :ok = WAL.append(state.wal, Events.JobDone.new(job, result))
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

  defp maybe_create_snapshot(state = %{snapshot_period: period, last_snapshot: last_snapshot})
       when period <= last_snapshot,
       do: create_snapshot(state)

  defp maybe_create_snapshot(state),
    do: %{state | last_snapshot: state.last_snapshot + 1}

  defp create_snapshot(state = %{wal: wal, job_module: job_module, queue: queue}) do
    :ok = WAL.compact(wal, Events.QueueSnapshot.new(job_module, queue))
    state
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
        :ok = WAL.append(state.wal, Events.JobStarted.new(job))
        demand = state.demand - 1
        state = %{state | queue: queue, demand: demand}
        events = [job | events]
        emit_events(state, events)

      # probably worth it to change this to {:error, :wait}
      {:wait, _} ->
        {state, Enum.reverse(events)}

      {:error, :empty} ->
        {state, Enum.reverse(events)}
    end
  end
end
