defmodule ExJob.PipelineTest do
  use ExUnit.Case

  alias ExJob.{Job, Pipeline}
  alias ExJob.WAL.Events

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

  setup do
    {:ok, _} = start_supervised({Registry, name: ExJob.Registry, keys: :unique})
    :ok
  end

  test "enqueues jobs" do
    {:ok, pid} = Pipeline.start_link(job_module: TestJob)
    job = Job.new(TestJob, [fn -> nil end])
    assert :ok == Pipeline.enqueue(pid, job)
  end

  test "runs enqueued jobs" do
    pid = self()
    ack_fn = fn -> send(pid, :ack) end

    {:ok, pid} = Pipeline.start_link(job_module: TestJob)
    job = Job.new(TestJob, [ack_fn])
    :ok = Pipeline.enqueue(pid, job)

    assert_receive :ack
  end

  describe "persistence" do
    test "recovers state from WAL" do
      test_pid = self()

      wait_forever_fn = fn ->
        send(test_pid, :ack)
        :timer.sleep(:infinity)
      end

      {:ok, _} = ExJob.WAL.start_link(path: ".ex_job.test.wal", name: PersistenceTestWAL)
      {:ok, pid} = Pipeline.start_link(job_module: TestJob, wal: PersistenceTestWAL)

      assert %{working: 0, failed: 0} = Pipeline.info(pid)

      job = Job.new(TestJob, [wait_forever_fn])
      :ok = Pipeline.enqueue(pid, job)
      assert_receive :ack

      assert %{working: 1, failed: 0} = Pipeline.info(pid)

      # kill currently working job
      :ok = Pipeline.stop(pid)
      refute Process.alive?(pid)

      {:ok, pid} = Pipeline.start_link(job_module: TestJob, wal: PersistenceTestWAL)
      assert %{working: 0, failed: 1} = Pipeline.info(pid)
    end

    test "writes snapshot periodically" do
      Application.put_env(:ex_job, :snapshot_period, 2)
      test_pid = self()

      wait_forever_fn = fn ->
        send(test_pid, :ack)
        :timer.sleep(:infinity)
      end

      job = fn -> Job.new(TestJob, [wait_forever_fn]) end

      {:ok, pid} = Pipeline.start_link(job_module: TestJob)
      {:ok, wal} = Pipeline.wal(TestJob)

      :ok = Pipeline.enqueue(pid, job.())
      :ok = Pipeline.enqueue(pid, job.())

      # Wait for both enqueued jobs to start
      assert_receive :ack
      assert_receive :ack

      {:ok, events} = ExJob.WAL.events(wal)
      refute Enum.any?(events, &match?(%Events.QueueSnapshot{}, &1))

      :ok = Pipeline.enqueue(pid, job.())
      assert_receive :ack

      {:ok, events} = ExJob.WAL.events(wal)
      assert Enum.any?(events, &match?(%Events.QueueSnapshot{}, &1))
    end
  end

  describe "concurrency" do
    defmodule SerializedJob do
      use ExJob.Job

      def concurrency, do: 1

      def perform(test_pid) do
        send(test_pid, {:waiting_job, self()})

        receive do
          :finish -> :ok
        end
      end
    end

    defmodule ParallelJob do
      use ExJob.Job

      def concurrency, do: 2

      def perform(test_pid) do
        send(test_pid, {:waiting_job, self()})

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

      send(job1, :finish)
      assert_receive {:waiting_job, job2}

      send(job2, :finish)
    end

    test "runs in parallel" do
      {:ok, pipeline} = Pipeline.start_link(job_module: ParallelJob, concurrency: 2)

      assert :ok == Pipeline.enqueue(pipeline, Job.new(ParallelJob, [self()]))
      assert :ok == Pipeline.enqueue(pipeline, Job.new(ParallelJob, [self()]))

      assert_receive {:waiting_job, job1}
      assert_receive {:waiting_job, job2}
      assert job1 != job2

      send(job1, :finish)
      send(job2, :finish)
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
      ack_fn = fn -> send(pid, :ack) end
      {:ok, pid} = Pipeline.start_link(job_module: TestJob)
      job = Job.new(TestJob, [ack_fn])

      :ok = Pipeline.enqueue(pid, job)
      assert_receive :ack
      :timer.sleep(10)

      info = Pipeline.info(pid)
      assert info.pending == 0
      assert info.processed == 1
      assert info.working == 0
      assert info.failed == 0
    end

    test "increments failed count" do
      pid = self()
      ack_fn = fn -> send(pid, :ack) end
      {:ok, pid} = Pipeline.start_link(job_module: FailingTestJob)
      job = Job.new(FailingTestJob, [ack_fn])

      :ok = Pipeline.enqueue(pid, job)
      assert_receive :ack
      :timer.sleep(10)

      info = Pipeline.info(pid)
      assert info.pending == 0
      assert info.processed == 0
      assert info.working == 0
      assert info.failed == 1
    end
  end
end
