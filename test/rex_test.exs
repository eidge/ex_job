defmodule RexTest do
  use ExUnit.Case
  doctest Rex

  defmodule TestJob do
    use Rex.Job

    def perform(test_pid) do
      send(test_pid, :test_job_ack)
    end
  end

  test "processes a job" do
    {:ok, _} = Rex.QueueManager.Supervisor.start_link
    :ok = Rex.enqueue(TestJob, [self()])
    assert_receive :test_job_ack
  end
end
