defmodule ExJob.GroupDispatcher do
  @moduledoc false

  use Supervisor

  def start_link(_opts), do: Supervisor.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_) do
    Supervisor.init(children(), strategy: :one_for_one)
  end

  defp children do
    [{Registry, keys: :unique, name: __MODULE__.Registry}]
  end

  def dispatch(queue_manager, queue_name) do
    pid = worker_for(queue_name)
    :ok = ExJob.Runner.run(pid, queue_manager, queue_name)
  end

  defp worker_for(queue_name) do
    name = {:via, Registry, {__MODULE__.Registry, queue_name}}
    case ExJob.Runner.Supervisor.start_child([name: name]) do
      {:ok, pid} -> pid
      {:error, {:already_started, other_pid}} -> other_pid
    end
  end
end
