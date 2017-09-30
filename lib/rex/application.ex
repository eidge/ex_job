defmodule Rex.Application do
  @moduledoc false

  use Application

  alias Rex.QueueManager

  def start(_type, _args) do
    children = [QueueManager.Supervisor]
    opts = [strategy: :one_for_one, name: Rex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
