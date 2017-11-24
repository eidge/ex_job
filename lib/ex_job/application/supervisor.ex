defmodule ExJob.Application.Supervisor do
  use Supervisor

  alias ExJob.{QueueManager, Runner}

  def start_link(_args \\ []) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(nil) do
    Supervisor.init(children(), strategy: :one_for_one)
  end

  defp children do
    [QueueManager.Supervisor, Runner.Supervisor]
  end
end
