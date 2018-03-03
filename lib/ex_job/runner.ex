defmodule ExJob.Runner do
  @moduledoc false

  use GenServer

  alias ExJob.QueueManager

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def init(nil), do: {:ok, nil}

  def run(pid, queue_manager, queue_name) do
    GenServer.cast(pid, {:run, queue_manager, queue_name})
  end

  def run_and_exit(pid, queue_manager, queue_name) do
    GenServer.cast(pid, {:run_and_exit, queue_manager, queue_name})
  end

  def handle_cast({:run, queue_manager, queue_name}, state) do
    do_run(queue_manager, queue_name)
    {:noreply, state}
  end

  def handle_cast({:run_and_exit, queue_manager, queue_name}, state) do
    do_run(queue_manager, queue_name)
    {:stop, :normal, state}
  end

  defp do_run(queue_manager, queue_name) do
    case QueueManager.dequeue(queue_manager, queue_name) do
      {:ok, job} ->
        case apply(job.module, :perform, job.arguments) do
          :ok -> QueueManager.notify_success(queue_manager, job)
          :error -> QueueManager.notify_failure(queue_manager, job)
          {:error, _} -> QueueManager.notify_failure(queue_manager, job)
          return_value -> raise ArgumentError, "Expected `#{job.module}.perform/n` to return :ok, :error or {:error, reason}, got #{inspect(return_value)}"
        end
      {:wait, _} ->
        :timer.sleep(20)
        do_run(queue_manager, queue_name)
    end
  end
end
