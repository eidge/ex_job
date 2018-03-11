defmodule ExJob.PipelineTest do
  use ExUnit.Case

  alias ExJob.{Job, Pipeline}

  defmodule TestJob do
    use ExJob.Job

    def perform(fun \\ fn -> nil end) do
      fun.()
      :ok
    end
  end

  defmodule FailingTestJob do
    use ExJob.Job

    def perform(fun \\ fn -> nil end) do
      fun.()
      :error
    end
  end

  test "enqueues jobs" do
    {:ok, pid} = Pipeline.start_link(job_module: TestJob)
    job = Job.new(TestJob, [fn -> nil end])
    assert :ok == Pipeline.enqueue(pid, job)
  end

  test "runs enqueued jobs" do
    pid = self()
    ack_fn = fn -> send pid, :ack end

    {:ok, pid} = Pipeline.start_link(job_module: TestJob)
    job = Job.new(TestJob, [ack_fn])
    :ok = Pipeline.enqueue(pid, job)

    assert_receive :ack
  end

  describe "concurrency" do
    defmodule SerializedJob do
      use ExJob.Job

      def concurrency, do: 1

      def perform(test_pid) do
        send test_pid, {:waiting_job, self()}
        receive do
          :finish -> :ok
        end
      end
    end

    defmodule ParallelJob do
      use ExJob.Job

      def concurrency, do: 2

      def perform(test_pid) do
        send test_pid, {:waiting_job, self()}
        receive do
          :finish -> :ok
        end
      end
    end

    test "is serializable" do
      {:ok, pipeline} = Pipeline.start_link(job_module: SerializedJob)

      assert :ok == Pipeline.enqueue(pipeline, Job.new(SerializedJob, [self()]))
      assert_receive {:waiting_job, job1}

      assert :ok == Pipeline.enqueue(pipeline, Job.new(SerializedJob, [self()]))
      refute_receive {:waiting_job, _job2}

      send job1, :finish
      assert_receive {:waiting_job, job2}

      send job2, :finish
    end

    test "runs in parallel" do
      {:ok, pipeline} = Pipeline.start_link(job_module: ParallelJob, concurrency: 2)

      assert :ok == Pipeline.enqueue(pipeline, Job.new(ParallelJob, [self()]))
      assert :ok == Pipeline.enqueue(pipeline, Job.new(ParallelJob, [self()]))

      assert_receive {:waiting_job, job1}
      assert_receive {:waiting_job, job2}
      assert job1 != job2

      send job1, :finish
      send job2, :finish
    end
  end

  describe "info/1" do
    test "starts with all metrics zeroed out" do
      {:ok, pid} = Pipeline.start_link(job_module: TestJob)
      info = Pipeline.info(pid)
      assert info.pending == 0
      assert info.processed == 0
      assert info.working == 0
      assert info.failed == 0
    end

    test "increments processed count" do
      pid = self()
      ack_fn = fn -> send pid, :ack end
      {:ok, pid} = Pipeline.start_link(job_module: TestJob)
      job = Job.new(TestJob, [ack_fn])

      :ok = Pipeline.enqueue(pid, job)
      assert_receive :ack

      info = Pipeline.info(pid)
      assert info.pending == 0
      assert info.processed == 1
      assert info.working == 0
      assert info.failed == 0
    end

    test "increments failed count" do
      pid = self()
      ack_fn = fn -> send pid, :ack end
      {:ok, pid} = Pipeline.start_link(job_module: FailingTestJob)
      job = Job.new(FailingTestJob, [ack_fn])

      :ok = Pipeline.enqueue(pid, job)
      assert_receive :ack

      info = Pipeline.info(pid)
      assert info.pending == 0
      assert info.processed == 0
      assert info.working == 0
      assert info.failed == 1
    end
  end
end
