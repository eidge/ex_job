defmodule ExJob.QueueManager.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, nil, opts)
  end

  def init(_) do
    Supervisor.init(children(), strategy: :rest_for_one)
  end

  defp children do
    [
      ExJob.GroupDispatcher,
      ExJob.Dispatcher,
      ExJob.QueueManager,
    ]
  end
end
