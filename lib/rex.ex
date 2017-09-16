defmodule Rex do
  @moduledoc """
  Documentation for Rex.
  """

  @doc """
  Enqueues a job that will be processed by **job_module** with **args**
  passed to it.
  """
  def enqueue(job_module, args \\ []) do
    job = Rex.Job.new(job_module, args)
    :ok = Rex.QueueManager.enqueue(job)
    :ok = job.dispatcher.dispatch(Rex.QueueManager, job.queue_name)
    :ok
  end
end
