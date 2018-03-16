defmodule ExJobTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  defmodule TestJob do
    use ExJob.Job

    def perform(test_pid) do
      send(test_pid, :test_job_ack)
      :ok
    end
  end

  defmodule WaitToDie do
    use ExJob.Job

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
    use ExJob.Job

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
    use ExJob.Job

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
    use ExJob.Job

    def perform do
      :invalid_return_value
    end
  end

  setup do
    start_supervised(ExJob.Application.Supervisor)
    :ok
  end

  describe "persistence" do
    alias ExJob.WAL.Events.{FileCreated, JobEnqueued, JobStarted, JobDone}

    defmodule WALJob do
      use ExJob.Job

      defstruct [:job_module]

      def perform(return_value) do
        ExJob.WAL.append(%WALJob{job_module: WALJob})
        return_value
      end
    end

    test "writes to WAL when is successful" do
      :ok = ExJob.enqueue(WALJob, [:ok])
      events = wait_for_wal_events(5)
      assert [
        %FileCreated{},
        %JobEnqueued{},
        %JobStarted{},
        %WALJob{},
        %JobDone{state: :success}
      ] = events
    end

    test "writes to WAL when it fails" do
      :ok = ExJob.enqueue(WALJob, [:error])
      events = wait_for_wal_events(5)
      assert [
        %FileCreated{},
        %JobEnqueued{},
        %JobStarted{},
        %WALJob{},
        %JobDone{state: :failure}
      ] = events
    end

    defp wait_for_wal_events(n, timeout \\ 100, elapsed \\ 0) do
      interval = 10
      {:ok, events} = ExJob.WAL.events(WALJob)
      count = Enum.count(events)
      if count == n || elapsed > timeout do
        assert count == n
        events
      else
        :timer.sleep(interval)
        wait_for_wal_events(n, timeout, elapsed + interval)
      end
    end
  end

  describe "enqueue/2" do
    test "processes a job" do
      :ok = ExJob.enqueue(TestJob, [self()])
      assert_receive :test_job_ack
    end

    test "runs jobs in parallel for the same queue" do
      :ok = ExJob.enqueue(WaitToDie, [self()])
      assert_receive {:ping, pid1}

      :ok = ExJob.enqueue(WaitToDie, [self()])
      assert_receive {:ping, pid2}, 1000
      refute pid1 == pid2

      WaitToDie.terminate(pid1)
      WaitToDie.terminate(pid2)
    end

    test "runs jobs in parallel for different queues" do
      :ok = ExJob.enqueue(WaitToDie, [self()])
      assert_receive {:ping, pid1}

      :ok = ExJob.enqueue(AnotherWaitToDie, [self()])
      assert_receive {:ping, pid2}
      refute pid1 == pid2

      WaitToDie.terminate(pid1)
      AnotherWaitToDie.terminate(pid2)
    end

    test "runs jobs synchronously for the same queue" do
      :ok = ExJob.enqueue(GroupedWaitToDie, ["one_key", self()])
      assert_receive {:ping, pid1, "one_key"}

      :ok = ExJob.enqueue(GroupedWaitToDie, ["other_key", self()])
      assert_receive {:ping, pid2, "other_key"}

      # pid1 is still waiting for a message, so this job will only
      # run after pid1 terminates.
      :ok = ExJob.enqueue(GroupedWaitToDie, ["one_key", self()])
      refute_receive {:ping, _, "one_key"}

      GroupedWaitToDie.terminate(pid1)
      assert_receive {:ping, pid3, "one_key"}, 5_000

      GroupedWaitToDie.terminate(pid2)
      GroupedWaitToDie.terminate(pid3)
    end

    @tag :capture_log
    test "raises exception if job does not return one of :ok, :error or {:error, reason}" do
      enqueue_invalid_job_fn = fn ->
        :ok = ExJob.enqueue(InvalidJob)
        :timer.sleep(20)
      end
      assert capture_log(enqueue_invalid_job_fn) =~ "Expected `Elixir.ExJobTest.InvalidJob.perform/n` to return :ok, :error or {:error, reason}, got :invalid_return_value"
    end

    test "raises helpful exception if second argument is not a list" do
      assert_raise ArgumentError,
        "expected list, got ExJob.enqueue(ExJobTest.TestJob, \"not a list\")",
        fn -> ExJob.enqueue(TestJob, "not a list") end
    end
  end

  describe "info/0" do
    defmodule StepJob do
      use ExJob.Job

      def group_by(_), do: 1

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
      info = ExJob.info()
      assert info.pending == 0
      assert info.processed == 0
      assert info.working == 0
      assert info.failed == 0
      assert info.queues == 0
    end

    test "follows job progress" do
      # Starts two grouped jobs, second job will be pending
      # until the first one finishes.
      :ok = ExJob.enqueue(StepJob, [self()])
      :ok = ExJob.enqueue(StepJob, [self()])

      {:ok, pid1} = StepJob.wait_for_job_to_start

      :timer.sleep(10)
      info = ExJob.info()
      assert info.pending == 1
      assert info.working == 1
      assert info.processed == 0
      assert info.failed == 0

      :ok = StepJob.finish_job(pid1)

      {:ok, pid2} = StepJob.wait_for_job_to_start
      :ok = StepJob.fail_job(pid2)

      :timer.sleep(10)
      info = ExJob.info()
      assert info.pending == 0
      assert info.working == 0
      assert info.processed == 1
      assert info.failed == 1
    end
  end
end
