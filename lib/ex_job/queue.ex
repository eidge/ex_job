defprotocol ExJob.Queue do
  @doc "Implements queue logic for the QueueManager to handle"

  def enqueue(queue, job)
  def dequeue(queue)
  def done(queue, job, result)
  def size(queue)
  def size(queue, state)
end

defmodule ExJob.Queue.NotWorkingError do
  defexception message: "Job was not found in the :working queue"
end
