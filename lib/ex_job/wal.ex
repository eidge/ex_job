defmodule ExJob.WAL do
  use GenServer

  alias ExJob.{WAL, Queue}
  alias ExJob.WAL.Events

  def start_link(path, options \\ [name: __MODULE__]) do
    GenServer.start_link(__MODULE__, path, options)
  end

  def init(path) do
    file_mod = Application.get_env(:ex_job, :wal_file_mod, WAL.File)
    :ok = File.mkdir_p(path)
    {:ok, %{file_mod: file_mod, path: path, files: %{}}}
  end

  def append(wal \\ __MODULE__, event) do
    GenServer.call(wal, {:append, event})
  end

  def events(wal \\ __MODULE__, job_module) do
    GenServer.call(wal, {:events, job_module})
  end

  def read(wal \\ __MODULE__, job_module) do
    GenServer.call(wal, {:read, job_module})
  end

  def handle_call({:append, event}, _from, state) do
    {state, file} = find_or_create_file(state, event)
    :ok = state.file_mod.append(file, event)
    {:reply, :ok, state}
  end

  def handle_call({:events, job_module}, _from, state) do
    events = read_events(state, job_module)
    {:reply, {:ok, events}, state}
  end

  def handle_call({:read, job_module}, _from, state) do
    {state, _file} = find_or_create_file(state, %{job_module: job_module})
    events = read_events(state, job_module)
    queue = apply_events(job_module.new_queue(), events)
    queue = fail_working_jobs(queue)
    {:reply, {:ok, queue}, state}
  end

  defp find_or_create_file(state, event) do
    file = Map.get(state.files, event.job_module)
    if file do
      {state, file}
    else
      file = create_file(state, event)
      state = put_in(state, [:files, event.job_module], file)
      {state, file}
    end
  end

  defp create_file(state, %{job_module: job_module}) do
    file_path = file_path(state.path, job_module)
    {:ok, file} = state.file_mod.open(file_path)
    :ok = state.file_mod.append(file, WAL.Events.FileCreated.new(job_module))
    file
  end

  defp file_path(path, job_module) do
    module_file = job_module |> to_string |> String.replace(".", "") |> Macro.underscore
    Path.join(path, module_file)
  end

  defp read_events(state, job_module) do
    with \
      {:ok, file} <- Map.fetch(state.files, job_module),
      {:ok, events} <- state.file_mod.read(file)
    do
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
    {:ok, queue} = case event do
      %Events.FileCreated{} ->
        {:ok, queue}
      %Events.JobEnqueued{job: job} ->
        Queue.enqueue(queue, job)
      %Events.JobStarted{} ->
        {:ok, queue, _} = Queue.dequeue(queue)
        {:ok, queue}
      %Events.JobDone{state: state, job: job} ->
        Queue.done(queue, job, state)
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
