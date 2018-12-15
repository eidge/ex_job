defmodule ExJob.WAL do
  use GenServer

  alias ExJob.{WAL, Queue}
  alias ExJob.WAL.{State, Events}

  def start_link(args \\ []) do
    path = Keyword.get(args, :path)
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, path, name: name)
  end

  def init(path) do
    file_mod = Application.get_env(:ex_job, :wal_file_mod, WAL.File)
    file = create_file(path, file_mod)
    {:ok, %{file_mod: file_mod, file: file}}
  end

  defp create_file(file_path, file_mod) do
    {:ok, file} = State.restore_or_create(file_path, file_mod: file_mod)
    file
  end

  def append(wal, event) do
    GenServer.call(wal, {:append, event})
  end

  def events(wal) do
    GenServer.call(wal, :events)
  end

  def read(wal, job_module) do
    GenServer.call(wal, {:read, job_module})
  end

  def compact(wal, event = %Events.QueueSnapshot{}) do
    GenServer.call(wal, {:compact, event})
  end

  def handle_call({:append, event}, _from, state) do
    :ok = state.file_mod.append(state.file.current_file, event)
    {:reply, :ok, state}
  end

  def handle_call(:events, _from, state) do
    events = read_events(state)
    {:reply, {:ok, events}, state}
  end

  def handle_call({:read, job_module}, _from, state) do
    events = read_events(state)
    wal_size = Enum.count(events)
    queue = apply_events(job_module.new_queue(), events)
    queue = fail_working_jobs(queue)
    {:reply, {:ok, queue, wal_size}, state}
  end

  def handle_call({:compact, event}, _from, state) do
    {:ok, file} = State.compact(state.file, event)
    state = %{state | file: file}
    {:reply, :ok, state}
  end

  defp read_events(state) do
    with {:ok, file} <- Map.fetch(state, :file),
         {:ok, events} <- state.file_mod.read(file.current_file) do
      events
    else
      :error -> []
      {:error, :enoent} -> []
    end
  end

  defp apply_events(queue, events) do
    Enum.reduce(events, queue, &apply_event(&2, &1))
  end

  defp apply_event(queue, event) do
    {:ok, queue} =
      case event do
        %Events.QueueSnapshot{} ->
          {:ok, event.snapshot}

        %Events.JobEnqueued{job: job} ->
          Queue.enqueue(queue, job)

        %Events.JobStarted{} ->
          {:ok, queue, _} = Queue.dequeue(queue)
          {:ok, queue}

        %Events.JobDone{state: state, job: job} ->
          Queue.done(queue, job, state)

        _ ->
          {:ok, queue}
      end

    queue
  end

  defp fail_working_jobs(queue) do
    working_jobs_when_process_failed = Queue.working(queue)

    Enum.reduce(working_jobs_when_process_failed, queue, fn job, queue ->
      {:ok, queue} = Queue.done(queue, job, :failure)
      queue
    end)
  end
end
