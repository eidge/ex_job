defmodule ExJob.Pipeline do
  @moduledoc """
  A Pipeline represents the workflow for enqueueing and consuming work
  from a single queue.

  Each pipeline can have different queue, worker pool and dequeue strategies.
  """

  use Supervisor

  alias ExJob.Pipeline.{Source, Multiplexer}

  def start_link(args \\ [])  do
    job_module = Keyword.get(args, :job_module)
    opts = Keyword.get(args, :options, [])
    Supervisor.start_link(__MODULE__, job_module, opts)
  end

  def stop(supervisor, reason \\ :normal) do
    Supervisor.stop(supervisor, reason)
  end

  def init(job_module) do
    children = children_for(job_module)
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp children_for(job_module) do
    [
      {Source, job_module: job_module, options: [name: source_name(job_module)]},
      {Multiplexer, job_module: job_module, subscribe_to: [source_name(job_module)]}
    ]
  end

  defp source_name(job_module), do: String.to_atom("#{job_module}Source")

  def enqueue(supervisor, job) do
    source = source(supervisor)
    Source.enqueue(source, job)
  end

  defp source(supervisor) do
    {_, pid, _, _} = supervisor
    |> Supervisor.which_children
    |> Enum.find(fn {_, _, _, modules} -> modules == [Source] end)
    pid
  end

  def info(supervisor) do
    source = source(supervisor)
    Source.info(source)
  end
end
