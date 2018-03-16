defmodule ExJob.Queue.SimpleQueue do
  @moduledoc false

  defstruct [:pending, :working, processed_count: 0, failed_count: 0]

  def new do
    %__MODULE__{pending: :queue.new, working: Map.new}
  end

  def from_list(list) when is_list(list) do
    pending = :queue.from_list(list)
    %__MODULE__{pending: pending, working: Map.new}
  end
end

defimpl ExJob.Queue, for: ExJob.Queue.SimpleQueue do
  alias ExJob.Queue.SimpleQueue

  def enqueue(queue, job) do
    pending = :queue.in(job, queue.pending)
    {:ok, %SimpleQueue{queue | pending: pending}}
  end

  def dequeue(queue) do
    with \
      {{_value, job}, pending} <- :queue.out(queue.pending),
      working <- Map.put(queue.working, job.ref, job),
      queue <- %SimpleQueue{queue | pending: pending, working: working}
    do
      {:ok, queue, job}
    else
      {:empty, _queue} -> {:error, :empty}
    end
  end

  def done(queue, job, result) do
    if Map.has_key?(queue.working, job.ref) do
      queue = queue
      |> increment(map_result_to_count_key(result))
      |> remove_from_working(job)
      {:ok, queue}
    else
      raise(ExJob.Queue.NotWorkingError)
    end
  end

  defp map_result_to_count_key(:success), do: :processed_count
  defp map_result_to_count_key(:failure), do: :failed_count

  defp remove_from_working(queue, job) do
    %SimpleQueue{queue | working: Map.delete(queue.working, job.ref)}
  end

  def size(queue), do: size(queue, :pending)
  def size(queue, :pending) do
    pending_queue = Map.get(queue, :pending)
    :queue.len(pending_queue)
  end
  def size(queue, :working) do
    pending_map = Map.get(queue, :working)
    Map.keys(pending_map) |> Enum.count
  end

  defp increment(queue, count_type) do
    Map.update!(queue, count_type, &(&1 + 1))
  end

  def working(queue) do
    Map.values(queue.working)
  end
end
