defmodule ExJob.Dispatcher do
  @moduledoc false

  use GenServer

  alias ExJob.Runner

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(nil), do: {:ok, nil}

  def dispatch(queue_manager, queue_name) do
    :ok = GenServer.cast(__MODULE__, {:dispatch, queue_manager, queue_name})
  end

  def handle_cast({:dispatch, queue_manager, queue_name}, state) do
    {:ok, pid} = Runner.Supervisor.start_child()
    Runner.run_and_exit(pid, queue_manager, queue_name)
    {:noreply, state}
  end
end
