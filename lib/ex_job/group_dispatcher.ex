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
    case Registry.lookup(__MODULE__.Registry, queue_name) do
      [] -> start_worker(queue_name)
      [{_, worker}] -> worker
    end
  end

  defp start_worker(queue_name) do
    # dispatch/2 will be called by foreign processes, meaning there is a race
    # condition between creating a process and registering it.
    #
    # Because of that, if when we try to register the process it already exists,
    # we kill the newly created process and re-use the existing one.
    #
    # We could prevent this by using a process to serialize access to the
    # registry but it would make the entire thing slower.

    # Can probably use the fact that the supervisor takes an id an returns
    # already started and in that way get rid of the Registry
    {:ok, pid} = ExJob.Runner.Supervisor.start_child()
    case Registry.register(__MODULE__.Registry, queue_name, pid) do
      {:ok, _} -> pid
      {:error, {:already_registered, other_pid}} ->
        Process.exit(pid, :kill)
        other_pid
    end
  end
end
