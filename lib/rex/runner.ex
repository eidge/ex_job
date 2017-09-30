defmodule Rex.Runner do
  use GenServer

  alias Rex.QueueManager

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def init(nil), do: {:ok, nil}

  def run(pid, queue_manager, queue_name) do
    GenServer.cast(pid, {:run, queue_manager, queue_name})
  end

  def handle_cast({:run, queue_manager, queue_name}, state) do
    do_run(queue_manager, queue_name)
    {:noreply, state}
  end

  defp do_run(queue_manager, queue_name) do
    {:ok, job} = QueueManager.dequeue(queue_manager, queue_name)
    case apply(job.module, :perform, job.arguments) do
      :ok -> QueueManager.notify_success(queue_manager, job)
      :error -> QueueManager.notify_failure(queue_manager, job)
      {:error, _} -> QueueManager.notify_failure(queue_manager, job)
      return_value -> raise ArgumentError, "Expected `#{job.module}.perform/n` to return :ok, :error or {:error, reason}, got #{inspect(return_value)}"
    end
  end
end
