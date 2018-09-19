defmodule ExJob.CentralTest do
  use ExUnit.Case

  alias ExJob.Central

  defmodule TestJob do
    use ExJob.Job

    def perform do
      :ok
    end
  end

  setup do
    spec = %{
      id: WAL,
      start: {GenServer, :start_link, [ExJob.WAL, ".test_wal", [name: ExJob.WAL]]}
    }

    {:ok, _} = start_supervised(spec)
    :ok
  end

  describe "pipeline_for/2" do
    test "starts named pipeline for job if it doesn't exist yet" do
      {:ok, central} = Central.start_link([])
      refute Process.whereis(ExJob.CentralTest.TestJobPipeline)
      {:ok, _} = Central.pipeline_for(central, TestJob)
      assert Process.whereis(ExJob.CentralTest.TestJobPipeline)
    end

    test "returns existing pipeline" do
      {:ok, central} = Central.start_link([])
      {:ok, pipeline} = Central.pipeline_for(central, TestJob)
      assert {:ok, ^pipeline} = Central.pipeline_for(central, TestJob)
    end
  end
end
