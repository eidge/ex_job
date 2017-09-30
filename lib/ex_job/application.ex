defmodule ExJob.Application do
  @moduledoc false

  use Application

  alias ExJob.QueueManager

  def start(_type, _args) do
    children = [QueueManager.Supervisor]
    opts = [strategy: :one_for_one, name: ExJob.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
