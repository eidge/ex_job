defmodule ExJob.Pipeline do
  @moduledoc """
  A Pipeline represents the workflow for enqueueing and consuming work
  from a single queue.

  Each pipeline can have different queue, dequeue and worker pool strategies.
  """

  use Supervisor

  alias ExJob.WAL
  alias ExJob.Pipeline.{Source, Multiplexer}

  def start_link(args \\ []) do
    job_module = Keyword.get(args, :job_module)
    opts = Keyword.get(args, :options, [])
    wal = Keyword.get(args, :wal)
    Supervisor.start_link(__MODULE__, {job_module, wal}, opts)
  end

  def stop(supervisor, reason \\ :normal) do
    Supervisor.stop(supervisor, reason)
  end

  def init({job_module, wal}) do
    children = children_for(job_module, wal)
    Supervisor.init(children, strategy: :one_for_one)
  end

  def wal(job_module), do: {:ok, wal_name_via(job_module)}

  defp children_for(job_module, nil) do
    [
      wal_spec(job_module),
      source_spec(job_module),
      multiplexer_spec(job_module)
    ]
  end

  defp children_for(job_module, wal) do
    [
      source_spec(job_module, wal),
      multiplexer_spec(job_module)
    ]
  end

  defp wal_spec(job_module), do: {WAL, path: wal_path(job_module), name: wal_name_via(job_module)}

  defp source_spec(job_module), do: source_spec(job_module, wal_name_via(job_module))

  defp source_spec(job_module, wal),
    do: {Source, job_module: job_module, wal: wal, options: [name: source_name_via(job_module)]}

  defp multiplexer_spec(job_module),
    do: {Multiplexer, job_module: job_module, subscribe_to: [source_name_via(job_module)]}

  defp wal_path(job_module) do
    wal_dir = Application.get_env(:ex_job, :wal_path, ".ex_job/wal/")
    module_file = job_module |> to_string |> String.replace(".", "") |> Macro.underscore()
    Path.join(wal_dir, module_file)
  end

  defp source_name_via(job_module),
    do: {:via, Registry, {ExJob.Registry, source_name(job_module)}}

  defp source_name(job_module), do: "#{job_module}Source"

  defp wal_name_via(job_module),
    do: {:via, Registry, {ExJob.Registry, wal_name(job_module)}}

  defp wal_name(job_module), do: "#{job_module}WAL"

  def enqueue(supervisor, job) do
    source = source(supervisor)
    Source.enqueue(source, job)
  end

  defp source(supervisor) do
    {_, pid, _, _} =
      supervisor
      |> Supervisor.which_children()
      |> Enum.find(fn {_, _, _, modules} -> modules == [Source] end)

    pid
  end

  def info(supervisor) do
    source = source(supervisor)
    Source.info(source)
  end
end
