defmodule Rex.QueueManager.DispatcherTest do
  use ExUnit.Case, async: true

  alias Rex.QueueManager

  setup do
    {:ok, _} = QueueManager.Supervisor.start_link(dispatcher: QueueManager.Dispatcher)
    :ok
  end

  defmodule SleepJob do
    def perform(pid) do
      :timer.sleep(50)
      send pid, :done
    end
  end

  test "runs jobs in parallel" do
    # :timer starts automatically if it wasn't started yet, but it is slow to
    # start so if we don't start it beforehand, we can't guarantee tests will
    # run in the expected time.
    :ok = :timer.start

    :ok = QueueManager.enqueue(SleepJob, [self()])
    :ok = QueueManager.enqueue(SleepJob, [self()])
    :ok = QueueManager.enqueue(SleepJob, [self()])
    :ok = QueueManager.enqueue(SleepJob, [self()])
    :ok = QueueManager.enqueue(SleepJob, [self()])

    assert_receive :done, 100
    assert_receive :done, 10
    assert_receive :done, 10
    assert_receive :done, 10
    assert_receive :done, 10
  end
end
