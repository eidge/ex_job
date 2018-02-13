defmodule ExJob.QueueTest do
  use ExUnit.Case

  alias ExJob.Queue
  alias ExJob.Job

  defmodule TestJob do
    use ExJob.Job

    def perform(_) do
      :ok
    end
  end

  describe "enqueue/2" do
    test "enqueues a job" do
      queue = Queue.new
      assert Queue.size(queue) == 0
      assert {:ok, queue} = Queue.enqueue(queue, job())
      assert Queue.size(queue) == 1
    end
  end

  describe "dequeue/1" do
    test "dequeues jobs in FIFO order" do
      queue = Queue.new
      {:ok, queue} = Queue.enqueue(queue, job(1))
      {:ok, queue} = Queue.enqueue(queue, job(2))
      assert {:ok, queue, %Job{arguments: [1]}} = Queue.dequeue(queue)
      assert {:ok, _queue, %Job{arguments: [2]}} = Queue.dequeue(queue)
    end

    test "moves jobs to the working queue" do
      queue = Queue.from_list([job(1), job(2)])
      assert Queue.size(queue) == 2
      assert Queue.size(queue, :working) == 0

      assert {:ok, queue, _job} = Queue.dequeue(queue)
      assert Queue.size(queue) == 1
      assert Queue.size(queue, :working) == 1

      assert {:ok, queue, _job} = Queue.dequeue(queue)
      assert Queue.size(queue) == 0
      assert Queue.size(queue, :working) == 2
    end

    test "returns error if queue is empty" do
      queue = Queue.new
      assert {:error, :empty} = Queue.dequeue(queue)
    end
  end

  describe "done/3" do
    test "removes item from the working queue" do
      queue = Queue.new
      assert Queue.size(queue) == 0
      assert Queue.size(queue, :working) == 0

      {:ok, queue} = Queue.enqueue(queue, job(1))
      assert Queue.size(queue) == 1
      assert Queue.size(queue, :working) == 0

      {:ok, queue, job} = Queue.dequeue(queue)
      assert Queue.size(queue) == 0
      assert Queue.size(queue, :working) == 1

      {:ok, queue} = Queue.done(queue, job, :success)
      assert Queue.size(queue) == 0
      assert Queue.size(queue, :working) == 0
    end

    test "increments correct count" do
      job1 = job()
      job2 = job()
      queue = Queue.from_list([job1, job2])

      {:ok, queue, ^job1} = Queue.dequeue(queue)
      {:ok, queue, ^job2} = Queue.dequeue(queue)
      assert queue.processed_count == 0
      assert queue.failed_count == 0

      {:ok, queue} = Queue.done(queue, job1, :success)
      assert queue.processed_count == 1
      assert queue.failed_count == 0

      {:ok, queue} = Queue.done(queue, job2, :failure)
      assert queue.processed_count == 1
      assert queue.failed_count == 1
    end

    test "throws error if job is not currently working" do
      queue = Queue.new
      assert_raise ExJob.Queue.NotWorkingError, fn ->
        Queue.done(queue, job(), :success)
      end
    end
  end

  describe "from_list/1" do
    test "returns a new %Queue{} from the list" do
      queue = Queue.from_list([job(1), job(2)])
      assert {:ok, queue, %Job{arguments: [1]}} = Queue.dequeue(queue)
      assert {:ok, _queue, %Job{arguments: [2]}} = Queue.dequeue(queue)
    end

    test "returns an empty %Queue{} from an empty list" do
      queue = Queue.from_list([])
      assert Queue.size(queue) == 0
    end
  end

  describe "size/2" do
    test "returns size of pending jobs by default" do
      queue = Queue.new
      assert Queue.size(queue) == 0

      {:ok, queue} = Queue.enqueue(queue, job(1))
      assert Queue.size(queue) == 1

      {:ok, queue, _} = Queue.dequeue(queue)
      assert Queue.size(queue) == 0
    end

    test "returns size of working jobs" do
      queue = Queue.new
      assert Queue.size(queue, :working) == 0

      {:ok, queue} = Queue.enqueue(queue, job(1))
      assert Queue.size(queue, :working) == 0

      {:ok, queue, _} = Queue.dequeue(queue)
      assert Queue.size(queue, :working) == 1
    end
  end

  def job(value \\ nil) do
    ExJob.Job.new(TestJob, [value])
  end
end
