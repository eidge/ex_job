defmodule RexTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

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
      receive do
        :die -> :ok
      end
    end

    def terminate(pid) do
      send pid, :die
    end
  end

  defmodule AnotherWaitToDie do
    use Rex.Job

    def perform(pid) do
      send pid, {:ping, self()}
      receive do
        :die -> :ok
      end
    end

    def terminate(pid) do
      send pid, :die
    end
  end

  defmodule GroupedWaitToDie do
    use Rex.Job

    def group_by(key, _), do: key

    def perform(key, pid) do
      send pid, {:ping, self(), key}
      receive do
        :die -> :ok
      end
    end

    def terminate(pid) do
      send pid, :die
    end
  end

  defmodule InvalidJob do
    use Rex.Job

    def perform do
      :invalid_return_value
    end
  end

  setup do
    start_supervised(QueueManager.Supervisor)
    :ok
  end

  describe "enqueue/2" do
    test "processes a job" do
      :ok = Rex.enqueue(TestJob, [self()])
      assert_receive :test_job_ack
    end

    test "runs jobs in parallel for the same queue" do
      :ok = Rex.enqueue(WaitToDie, [self()])
      assert_receive {:ping, pid1}

      :ok = Rex.enqueue(WaitToDie, [self()])
      assert_receive {:ping, pid2}
      refute pid1 == pid2

      WaitToDie.terminate(pid1)
      WaitToDie.terminate(pid2)
    end

    test "runs jobs in parallel for different queues" do
      :ok = Rex.enqueue(WaitToDie, [self()])
      assert_receive {:ping, pid1}

      :ok = Rex.enqueue(AnotherWaitToDie, [self()])
      assert_receive {:ping, pid2}
      refute pid1 == pid2

      WaitToDie.terminate(pid1)
      AnotherWaitToDie.terminate(pid2)
    end

    test "runs jobs synchronously for the same queue" do
      :ok = Rex.enqueue(GroupedWaitToDie, ["one_key", self()])
      assert_receive {:ping, pid1, "one_key"}

      :ok = Rex.enqueue(GroupedWaitToDie, ["other_key", self()])
      assert_receive {:ping, pid2, "other_key"}

      # pid1 is still waiting for a message, so this job will only
      # run after pid1 terminates.
      :ok = Rex.enqueue(GroupedWaitToDie, ["one_key", self()])
      refute_receive {:ping, _, "one_key"}

      GroupedWaitToDie.terminate(pid1)
      assert_receive {:ping, pid3, "one_key"}

      GroupedWaitToDie.terminate(pid2)
      GroupedWaitToDie.terminate(pid3)
    end

    @tag :capture_log
    test "raises exception if job does not return one of :ok, :error or {:error, reason}" do
      enqueue_invalid_job_fn = fn ->
        :ok = Rex.enqueue(InvalidJob)
        :timer.sleep(20)
      end
      assert capture_log(enqueue_invalid_job_fn) =~ "Expected `Elixir.RexTest.InvalidJob.perform/n` to return :ok, :error or {:error, reason}, got :invalid_return_value"
    end

    test "raises helpful exception if second argument is not a list" do
      assert_raise ArgumentError,
        "expected list, got Rex.enqueue(RexTest.TestJob, \"not a list\")",
        fn -> Rex.enqueue(TestJob, "not a list") end
    end
  end

  describe "info/0" do
    defmodule StepJob do
      use Rex.Job

      def perform(pid) do
        send(pid, {:success_job_start, self()})
        receive do
          :finish_job_success -> :ok
          :finish_job_error -> :error
        end
      end

      def wait_for_job_to_start do
        receive do
          {:success_job_start, pid} -> {:ok, pid}
        end
      end

      def finish_job(pid) do
        send(pid, :finish_job_success)
        :ok
      end

      def fail_job(pid) do
        send(pid, :finish_job_error)
        :ok
      end
    end

    test "returns job metrics" do
      info = Rex.info()
      assert info.pending == 0
      assert info.processed == 0
      assert info.working == 0
      assert info.failed == 0
      assert info.queues == 0
    end

    test "follows job progress to success" do
      :ok = Rex.enqueue(StepJob, [self()])

      info = Rex.info()
      assert info.pending == 1
      assert info.working == 0
      assert info.processed == 0
      assert info.failed == 0

      {:ok, pid} = StepJob.wait_for_job_to_start

      info = Rex.info()
      assert info.pending == 0
      assert info.working == 1
      assert info.processed == 0
      assert info.failed == 0

      :ok = StepJob.finish_job(pid)
      :timer.sleep(10)

      info = Rex.info()
      assert info.pending == 0
      assert info.working == 0
      assert info.processed == 1
      assert info.failed == 0
    end

    test "follows job progress to failed" do
      :ok = Rex.enqueue(StepJob, [self()])

      info = Rex.info()
      assert info.pending == 1
      assert info.working == 0
      assert info.processed == 0
      assert info.failed == 0

      {:ok, pid} = StepJob.wait_for_job_to_start

      info = Rex.info()
      assert info.pending == 0
      assert info.working == 1
      assert info.processed == 0
      assert info.failed == 0

      :ok = StepJob.fail_job(pid)
      :timer.sleep(10)

      info = Rex.info()
      assert info.pending == 0
      assert info.working == 0
      assert info.processed == 0
      assert info.failed == 1
    end
  end
end
