defmodule Rex.QueueManagerTest do
  use ExUnit.Case

  alias Rex.QueueManager

  defmodule TestDispatcher do
    use GenServer

    def start_link(test_pid), do: GenServer.start_link(__MODULE__, test_pid, name: __MODULE__)
    def init(test_pid), do: {:ok, test_pid}

    def dispatch(queue_manager, queue_name) do
      :ok = GenServer.cast(__MODULE__, {:dispatch, queue_manager, queue_name})
    end

    def handle_cast({:dispatch, _queue_manager, queue_name}, test_pid) do
      send test_pid, {:dispatched, queue_name}
      {:noreply, test_pid}
    end
  end

  defmodule TestJob do
    use Rex.Job

    def perform() do
      :ok
    end
  end

  setup do
    {:ok, _} = TestDispatcher.start_link(self())
    :ok
  end

  describe "enqueue/3" do
    setup do
      {:ok, queue_manager} = QueueManager.start_link([], [])
      {:ok, queue_manager: queue_manager}
    end

    test "enqueues a job", ctx do
      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job())
    end

    test "creates a new queue if one does not exist yet", ctx do
      assert queue_count(ctx) == 0
      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job())
      assert queue_count(ctx) == 1
    end

    test "uses existing queue if it already exists", ctx do
      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job())
      assert queue_count(ctx) == 1

      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job())
      assert queue_count(ctx) == 1
    end
  end

  describe "dequeue/2" do
    defmodule NoOpDispatcher do
      def dispatch(_queue_manager, _queue), do: nil
    end

    setup do
      {:ok, queue_manager} = QueueManager.start_link([dispatcher: NoOpDispatcher], [])
      {:ok, queue_manager: queue_manager}
    end

    test "dequeues jobs in FIFO order", ctx do
      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job(1))
      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job(2))
      assert :ok = QueueManager.enqueue(ctx.queue_manager, new_job(3))

      assert {:ok, %{arguments: [1]}} = QueueManager.dequeue(ctx.queue_manager, TestJob)
      assert {:ok, %{arguments: [2]}} = QueueManager.dequeue(ctx.queue_manager, TestJob)
      assert {:ok, %{arguments: [3]}} = QueueManager.dequeue(ctx.queue_manager, TestJob)
      assert {:error, :empty} = QueueManager.dequeue(ctx.queue_manager, TestJob)
    end
  end

  defp queue_count(ctx) do
    {:ok, queues} = QueueManager.queues(ctx.queue_manager)
    Enum.count(queues)
  end

  def new_job(value \\ nil) do
    Rex.Job.new(TestJob, [value])
  end
end
