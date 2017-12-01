defmodule ExJob.Runner.Supervisor do
  use Supervisor

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(nil) do
    Supervisor.init(children(), strategy: :simple_one_for_one)
  end

  defp children do
    [child_spec()]
  end

  defp child_spec do
    Supervisor.child_spec(
      ExJob.Runner,
      start: {ExJob.Runner, :start_link, []},
      restart: :transient,
    )
  end

  def start_child(options \\ []) do
    Supervisor.start_child(__MODULE__, [options])
  end
end
