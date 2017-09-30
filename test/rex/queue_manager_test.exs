defmodule Rex.QueueManagerTest do
  use ExUnit.Case

  alias Rex.QueueManager

  defmodule TestJob do
    use Rex.Job

    def perform(_) do
      :ok
    end
  end

  setup do
    {:ok, queue_manager} = QueueManager.start_link([], [])
    {:ok, queue_manager: queue_manager}
  end

  describe "enqueue/3" do
    test "enqueues a job", ctx do
      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job())
    end

    test "creates a new queue if one does not exist yet", ctx do
      assert QueueManager.info(ctx.queue_manager).queues == 0
      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job())
      assert QueueManager.info(ctx.queue_manager).queues == 1
    end

    test "uses existing queue if it already exists", ctx do
      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job())
      assert QueueManager.info(ctx.queue_manager).queues == 1

      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job())
      assert QueueManager.info(ctx.queue_manager).queues == 1
    end

    test "marks job as pending", ctx do
      assert %{pending: 0, working: 0} = QueueManager.info(ctx.queue_manager)
      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job(1))
      assert %{pending: 1, working: 0} = QueueManager.info(ctx.queue_manager)
    end
  end

  describe "dequeue/2" do
    test "dequeues jobs in FIFO order", ctx do
      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job(1))
      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job(2))
      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job(3))

      assert {:ok, %{arguments: [1]}} = QueueManager.dequeue(ctx.queue_manager, TestJob)
      assert {:ok, %{arguments: [2]}} = QueueManager.dequeue(ctx.queue_manager, TestJob)
      assert {:ok, %{arguments: [3]}} = QueueManager.dequeue(ctx.queue_manager, TestJob)
      assert {:error, :empty} = QueueManager.dequeue(ctx.queue_manager, TestJob)
    end

    test "marks job as working", ctx do
      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job(1))
      assert %{pending: 1, working: 0} = QueueManager.info(ctx.queue_manager)

      assert {:ok, %{arguments: [1]}} = QueueManager.dequeue(ctx.queue_manager, TestJob)
      assert %{pending: 0, working: 1} = QueueManager.info(ctx.queue_manager)
    end
  end

  describe "notify_success/2" do
    test "marks job as completed successfully", ctx do
      import QueueManager, only: [info: 1]

      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job(1))
      assert %{pending: 1, working: 0, processed: 0, failed: 0} = info(ctx.queue_manager)

      assert {:ok, job} = QueueManager.dequeue(ctx.queue_manager, TestJob)
      assert %{pending: 0, working: 1, processed: 0, failed: 0} = info(ctx.queue_manager)

      :ok = QueueManager.notify_success(ctx.queue_manager, job)
      assert %{pending: 0, working: 0, processed: 1, failed: 0} = info(ctx.queue_manager)
    end

    @tag :capture_log
    test "fails if job is not in the working queue", ctx do
      job = new_job(1)
      assert :ok = QueueManager.enqueue(ctx.queue_manager, job)
      assert %{pending: 1, working: 0} = QueueManager.info(ctx.queue_manager)

      Process.flag :trap_exit, true
      catch_exit do
        QueueManager.notify_success(ctx.queue_manager, job)
      end

      pid = ctx.queue_manager
      assert_received({:EXIT, ^pid, {%QueueManager.NotWorkingError{}, _}})
    end
  end

  describe "notify_failure/2" do
    test "marks job as failed", ctx do
      import QueueManager, only: [info: 1]

      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job(1))
      assert %{pending: 1, working: 0, processed: 0, failed: 0} = info(ctx.queue_manager)

      assert {:ok, job} = QueueManager.dequeue(ctx.queue_manager, TestJob)
      assert %{pending: 0, working: 1, processed: 0, failed: 0} = info(ctx.queue_manager)

      :ok = QueueManager.notify_failure(ctx.queue_manager, job)
      assert %{pending: 0, working: 0, processed: 0, failed: 1} = info(ctx.queue_manager)
    end

    @tag :capture_log
    test "fails if job is not in the working queue", ctx do
      job = new_job(1)
      assert :ok = QueueManager.enqueue(ctx.queue_manager, job)
      assert %{pending: 1, working: 0} = QueueManager.info(ctx.queue_manager)

      Process.flag :trap_exit, true
      catch_exit do
        QueueManager.notify_success(ctx.queue_manager, job)
      end

      pid = ctx.queue_manager
      assert_received({:EXIT, ^pid, {%QueueManager.NotWorkingError{}, _}})
    end
  end

  describe "info/0" do
    test "starts with all metrics zeroed out", ctx do
      info = QueueManager.info(ctx.queue_manager)
      assert info.pending == 0
      assert info.processed == 0
      assert info.working == 0
      assert info.failed == 0
      assert info.queues == 0
    end
  end

  def new_job(value \\ nil) do
    Rex.Job.new(TestJob, [value])
  end
end
