defmodule Rex do
  @moduledoc """
  Documentation for Rex.
  """

  @doc """
  Enqueues a job that will be processed by **job_module** with **args**
  passed to it.
  """
  def enqueue(job_module, args \\ []) do
    Rex.QueueManager.enqueue(job_module, args)
    :ok
  end
end
