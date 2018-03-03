defmodule ExJob.Queue.GroupedQueue do
  @moduledoc false

  defmodule JobNotGroupedError do
    defexception message: "Job does not define group_by/n"
  end

  alias ExJob.Queue

  defstruct [queues: Map.new, working: Map.new, age: 0, ages: Map.new,
             processed_count: 0, failed_count: 0]

  def new do
    struct!(%__MODULE__{}, %{})
  end

  def from_list(list) when is_list(list) do
    Enum.reduce(list, new(), fn job, grouped_queue ->
      {:ok, grouped_queue} = Queue.enqueue(grouped_queue, job)
      grouped_queue
    end)
  end
end

defimpl ExJob.Queue, for: ExJob.Queue.GroupedQueue do
  alias ExJob.Queue
  alias ExJob.Queue.{GroupedQueue, SimpleQueue}

  def enqueue(%GroupedQueue{}, %{group_by: nil}), do: throw(JobNotGroupedError)
  def enqueue(grouped_queue = %GroupedQueue{}, job) do
    {:ok, queue} = get_queue(grouped_queue, job.group_by) |> Queue.enqueue(job)
    queues = Map.put(grouped_queue.queues, job.group_by, queue)
    ages = Map.update(grouped_queue.ages, job.group_by, [grouped_queue.age], fn ages ->
      ages ++ [grouped_queue.age]
    end)
    new_age = grouped_queue.age + 1
    {:ok, %GroupedQueue{grouped_queue | queues: queues, age: new_age, ages: ages}}
  end

  defp get_queue(grouped_queue, group_by),
    do: Map.get(grouped_queue.queues, group_by, SimpleQueue.new)

  def dequeue(grouped_queue = %GroupedQueue{}) do
    if size(grouped_queue, :pending) == 0 do
      {:error, :empty}
    else
      next_queue = next_queue(grouped_queue)

      if next_queue do
        {:ok, queue, job} = get_queue(grouped_queue, next_queue) |> Queue.dequeue
        queues = Map.put(grouped_queue.queues, next_queue, queue)
        working = Map.put(grouped_queue.working, next_queue, job)
        {:ok, %GroupedQueue{grouped_queue | queues: queues, working: working}, job}
      else
        {:wait, :all_groups_working}
      end
    end
  end

  defp next_queue(grouped_queue) do
    {queue, _} = Enum.min_by(grouped_queue.ages, fn {queue, [age | _]} ->
      if working?(grouped_queue, queue) do
        :infinity
      else
        age
      end
    end)

    if working?(grouped_queue, queue) do
      nil
    else
      queue
    end
  end

  defp working?(%{working: working}, queue), do: Map.has_key?(working, queue)

  def done(grouped_queue = %GroupedQueue{}, job, result) do
    if working?(grouped_queue, job.group_by) do
      grouped_queue = grouped_queue
      |> increment(map_result_to_count_key(result))
      |> remove_from_working(job)
      {:ok, grouped_queue}
    else
      raise(ExJob.Queue.NotWorkingError)
    end
  end

  defp map_result_to_count_key(:success), do: :processed_count
  defp map_result_to_count_key(:failure), do: :failed_count

  defp increment(queue, count_type) do
    Map.update!(queue, count_type, &(&1 + 1))
  end

  defp remove_from_working(grouped_queue, job) do
    working = Map.delete(grouped_queue.working, job.group_by)
    %GroupedQueue{grouped_queue | working: working}
  end

  def size(grouped_queue = %GroupedQueue{}), do: size(grouped_queue, :pending)
  def size(grouped_queue = %GroupedQueue{}, :pending) do
    grouped_queue.queues
    |> Map.values
    |> Enum.map(&Queue.size/1)
    |> Enum.sum
  end
  def size(grouped_queue = %GroupedQueue{}, :working) do
    Enum.count(grouped_queue.working)
  end
end
