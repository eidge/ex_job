defmodule ExJob.Queue do
  @moduledoc false

  defmodule NotWorkingError do
    defexception message: "Job was not found in the :working queue"
  end

  @enforce_keys [:pending, :working]
  defstruct [:pending, :working, processed_count: 0, failed_count: 0]

  def new do
    %__MODULE__{pending: :queue.new, working: Map.new}
  end

  def enqueue(queue = %__MODULE__{}, job) do
    pending = :queue.in(job, queue.pending)
    {:ok, %__MODULE__{queue | pending: pending}}
  end

  def dequeue(queue = %__MODULE__{}) do
    with \
      {{_value, job}, pending} <- :queue.out(queue.pending),
      working <- Map.put(queue.working, job.ref, job),
      queue <- %__MODULE__{queue | pending: pending, working: working}
    do
      {:ok, queue, job}
    else
      {:empty, _queue} -> {:error, :empty}
    end
  end

  def done(queue = %__MODULE__{}, job, result) do
    if Map.has_key?(queue.working, job.ref) do
      queue = increment(queue, map_result_to_count_key(result))
      queue = %__MODULE__{queue | working: Map.delete(queue.working, job.ref)}
      {:ok, queue}
    else
      raise(NotWorkingError)
    end
  end

  defp map_result_to_count_key(:success), do: :processed_count
  defp map_result_to_count_key(:failure), do: :failed_count

  def size(queue = %__MODULE__{}), do: size(queue, :pending)
  def size(queue = %__MODULE__{}, :pending) do
    pending_queue = Map.get(queue, :pending)
    :queue.len(pending_queue)
  end
  def size(queue = %__MODULE__{}, :working) do
    pending_map = Map.get(queue, :working)
    Map.keys(pending_map) |> Enum.count
  end

  def to_list(queue = %__MODULE__{}) do
    :queue.to_list(queue.pending)
  end

  def from_list(list) when is_list(list) do
    pending = :queue.from_list(list)
    %__MODULE__{pending: pending, working: Map.new}
  end

  defp increment(queue, count_type) do
    Map.update!(queue, count_type, &(&1 + 1))
  end
end
