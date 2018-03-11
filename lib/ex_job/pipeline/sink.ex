defmodule ExJob.Pipeline.Sink do
  use Task

  alias ExJob.{Job, Pipeline}

  def start_link(queue, job) do
    Task.start_link(__MODULE__, :perform, [queue, job])
  end

  def perform(queue, job) do
    case Job.run(job) do
      :ok -> Pipeline.Source.notify_success(queue, job)
      _ -> Pipeline.Source.notify_failure(queue, job)
    end
  end
end

