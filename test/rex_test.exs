defmodule RexTest do
  use ExUnit.Case
  doctest Rex

  defmodule TestJob do
    def perform(test_id) do
      send(test_id, :test_job_ack)
    end
  end

  test "processes a job" do
    :ok = Rex.enqueue(TestJob)
    assert_receive :test_job_ack
  end
end
