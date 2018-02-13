defmodule ExJob.GroupedQueueTest do
  use ExUnit.Case

  alias ExJob.GroupedQueue
  alias ExJob.Job

  defmodule TestJob do
    use ExJob.Job

    def group_by(value, nil), do: value
    def group_by(_, group_by), do: group_by

    def perform(_, _) do
      :ok
    end
  end

  describe "enqueue/2" do
    test "enqueues a job" do
      queue = GroupedQueue.new
      assert GroupedQueue.size(queue) == 0
      assert {:ok, queue} = GroupedQueue.enqueue(queue, job())
      assert GroupedQueue.size(queue) == 1
    end
  end

  describe "dequeue/1" do
    test "dequeues jobs in FIFO order" do
      queue = GroupedQueue.new
      {:ok, queue} = GroupedQueue.enqueue(queue, job(1, :group_1))
      {:ok, queue} = GroupedQueue.enqueue(queue, job(2, :group_2))
      assert GroupedQueue.size(queue) == 2
      assert {:ok, queue, %Job{arguments: [1, :group_1]}} = GroupedQueue.dequeue(queue)
      assert {:ok, _queue, %Job{arguments: [2, :group_2]}} = GroupedQueue.dequeue(queue)
    end

    test "dequeues jobs in FIFO order, skipping currently working groups" do
      jobs = [
        job(0, :group_1),
        job(1, :group_1),
        job(2, :group_2),
        job(3, :group_3),
        job(4, :group_3)
      ]

      queue = GroupedQueue.from_list(jobs)

      assert {:ok, queue, %Job{arguments: [0, :group_1]}} = GroupedQueue.dequeue(queue)
      assert {:ok, queue, %Job{arguments: [2, :group_2]}} = GroupedQueue.dequeue(queue)
      assert {:ok, queue, %Job{arguments: [3, :group_3]}} = GroupedQueue.dequeue(queue)

      {:ok, queue} = GroupedQueue.done(queue, Enum.at(jobs, 3), :success)
      {:ok, queue} = GroupedQueue.done(queue, Enum.at(jobs, 0), :failure)

      assert {:ok, queue, %Job{arguments: [1, :group_1]}} = GroupedQueue.dequeue(queue)
      assert {:ok, queue, %Job{arguments: [4, :group_3]}} = GroupedQueue.dequeue(queue)
    end

    test "moves jobs to the working queue" do
      queue = GroupedQueue.from_list([job(1), job(2)])
      assert GroupedQueue.size(queue) == 2
      assert GroupedQueue.size(queue, :working) == 0

      assert {:ok, queue, _job} = GroupedQueue.dequeue(queue)
      assert GroupedQueue.size(queue) == 1
      assert GroupedQueue.size(queue, :working) == 1

      assert {:ok, queue, _job} = GroupedQueue.dequeue(queue)
      assert GroupedQueue.size(queue) == 0
      assert GroupedQueue.size(queue, :working) == 2
    end

    test "returns :wait if there are pending jobs waiting for working queues to finish" do
      queue = GroupedQueue.new
      {:ok, queue} = GroupedQueue.enqueue(queue, job(1, :group_1))
      {:ok, queue} = GroupedQueue.enqueue(queue, job(2, :group_1))

      assert {:ok, queue, %Job{arguments: [1, :group_1]}} = GroupedQueue.dequeue(queue)
      assert {:wait, :all_groups_working} = GroupedQueue.dequeue(queue)
    end

    test "returns error if queue is empty" do
      queue = GroupedQueue.new
      assert {:error, :empty} = GroupedQueue.dequeue(queue)
    end
  end

  describe "done/3" do
    test "removes item from the working queue" do
      queue = GroupedQueue.new
      assert GroupedQueue.size(queue) == 0
      assert GroupedQueue.size(queue, :working) == 0

      {:ok, queue} = GroupedQueue.enqueue(queue, job(1))
      assert GroupedQueue.size(queue) == 1
      assert GroupedQueue.size(queue, :working) == 0

      {:ok, queue, job} = GroupedQueue.dequeue(queue)
      assert GroupedQueue.size(queue) == 0
      assert GroupedQueue.size(queue, :working) == 1

      {:ok, queue} = GroupedQueue.done(queue, job, :success)
      assert GroupedQueue.size(queue) == 0
      assert GroupedQueue.size(queue, :working) == 0
    end

    test "increments correct count" do
      job1 = job(1, :group_1)
      job2 = job(2, :group_2)
      queue = GroupedQueue.from_list([job1, job2])

      {:ok, queue, ^job1} = GroupedQueue.dequeue(queue)
      {:ok, queue, ^job2} = GroupedQueue.dequeue(queue)
      assert queue.processed_count == 0
      assert queue.failed_count == 0

      {:ok, queue} = GroupedQueue.done(queue, job1, :success)
      assert queue.processed_count == 1
      assert queue.failed_count == 0

      {:ok, queue} = GroupedQueue.done(queue, job2, :failure)
      assert queue.processed_count == 1
      assert queue.failed_count == 1
    end

    test "throws error if job is not currently working" do
      queue = GroupedQueue.new
      assert_raise ExJob.Queue.NotWorkingError, fn ->
        GroupedQueue.done(queue, job(), :success)
      end
    end
  end

  describe "from_list/1" do
    test "returns a new %GroupedQueue{} from the list" do
      job1 = job(1)
      job2 = job(2)
      queue = GroupedQueue.from_list([job1, job2])
      assert {:ok, queue, ^job1} = GroupedQueue.dequeue(queue)
      assert {:ok, _queue, ^job2} = GroupedQueue.dequeue(queue)
    end

    test "returns an empty %GroupedQueue{} from an empty list" do
      queue = GroupedQueue.from_list([])
      assert GroupedQueue.size(queue) == 0
    end
  end

  describe "size/2" do
    test "returns size of pending jobs by default" do
      queue = GroupedQueue.new
      assert GroupedQueue.size(queue) == 0

      {:ok, queue} = GroupedQueue.enqueue(queue, job(1))
      assert GroupedQueue.size(queue) == 1

      {:ok, queue, _} = GroupedQueue.dequeue(queue)
      assert GroupedQueue.size(queue) == 0
    end

    test "returns size of working jobs" do
      queue = GroupedQueue.new
      assert GroupedQueue.size(queue, :working) == 0

      {:ok, queue} = GroupedQueue.enqueue(queue, job(1))
      assert GroupedQueue.size(queue, :working) == 0

      {:ok, queue, _} = GroupedQueue.dequeue(queue)
      assert GroupedQueue.size(queue, :working) == 1
    end
  end

  def job(value \\ :value, group_by \\ nil) do
    ExJob.Job.new(TestJob, [value, group_by || value])
  end
end
