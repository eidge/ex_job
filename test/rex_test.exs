defmodule RexTest do
  use ExUnit.Case

  alias Rex.QueueManager

  defmodule TestJob do
    use Rex.Job

    def perform(test_pid) do
      send(test_pid, :test_job_ack)
    end
  end

  defmodule WaitToDie do
    use Rex.Job

    def perform(pid) do
      send pid, {:ping, self()}
      :timer.sleep(:infinity)
    end
  end

  defmodule AnotherWaitToDie do
    use Rex.Job

    def perform(pid) do
      send pid, {:ping, self()}
      :timer.sleep(:infinity)
    end
  end

  defmodule GroupedWaitToDie do
    use Rex.Job

    def group_by(key, _), do: key

    def perform(key, pid) do
      send pid, key
      :timer.sleep(:infinity)
    end
  end

  setup do
    {:ok, _} = QueueManager.Supervisor.start_link

    on_exit fn ->
      Process.exit(Process.whereis(QueueManager.Supervisor), :kill)
      :ok
    end

    :ok
  end

  test "processes a job" do
    :ok = Rex.enqueue(TestJob, [self()])
    assert_receive :test_job_ack
  end

  describe "dispatching mechanism" do
    test "runs jobs in parallel for the same queue" do
      :ok = Rex.enqueue(WaitToDie, [self()])
      assert_receive {:ping, pid1}

      :ok = Rex.enqueue(WaitToDie, [self()])
      assert_receive {:ping, pid2}
      refute pid1 == pid2
    end

    test "runs jobs in parallel for different queues" do
      :ok = Rex.enqueue(WaitToDie, [self()])
      assert_receive {:ping, pid1}

      :ok = Rex.enqueue(AnotherWaitToDie, [self()])
      assert_receive {:ping, pid2}
      refute pid1 == pid2
    end

    test "runs jobs synchronously for the same queue" do
      :ok = Rex.enqueue(GroupedWaitToDie, ["one_key", self()])
      assert_receive "one_key"

      :ok = Rex.enqueue(GroupedWaitToDie, ["other_key", self()])
      assert_receive "other_key"

      # one_key is still sleeping, so the second "one_key" will never run.
      :ok = Rex.enqueue(GroupedWaitToDie, ["one_key", self()])
      refute_receive "one_key"
    end
  end
end
