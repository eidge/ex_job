defprotocol ExJob.Queue do
  @doc "Implements a queue"

  def enqueue(queue, job)
  def dequeue(queue)
  def done(queue, job, result)
  def size(queue)
  def size(queue, state)
  def working(queue)
end

defmodule ExJob.Queue.NotWorkingError do
  defexception message: "Job was not found in the :working queue"
end
