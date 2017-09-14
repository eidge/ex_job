defmodule Rex.QueueManager.Supervisor do
  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    opts = Keyword.put_new(opts, :strategy, :rest_for_one)
    Supervisor.start_link(children(), opts)
  end

  defp children do
    [
      Rex.QueueManager.Dispatcher,
      Rex.QueueManager,
    ]
  end
end
