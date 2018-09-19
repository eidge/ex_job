defmodule ExJob.Central do
  @moduledoc false

  use DynamicSupervisor

  alias ExJob.Pipeline

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, nil, opts)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def pipeline_for(central \\ __MODULE__, job_module) when is_atom(job_module) do
    case Process.whereis(pipeline_name(job_module)) do
      nil -> start_pipeline(central, job_module)
      pid when is_pid(pid) -> {:ok, pid}
    end
  end

  defp start_pipeline(central, job_module) do
    case DynamicSupervisor.start_child(central, pipeline_spec(job_module)) do
      {:ok, _} = ok -> ok
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end

  defp pipeline_spec(job_module) do
    {Pipeline, job_module: job_module, options: [name: pipeline_name(job_module)]}
  end

  defp pipeline_name(job_module), do: String.to_atom("#{job_module}Pipeline")

  def info(pid \\ __MODULE__) do
    pipelines = pipelines(pid)
    infos = Enum.map(pipelines, &Pipeline.info(&1))
    info = reduce_infos(infos)
    %{info | queues: Enum.count(infos)}
  end

  defp pipelines(pid) do
    pid
    |> Supervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> pid end)
  end

  defp reduce_infos([]), do: empty_info()

  defp reduce_infos(infos) do
    Enum.reduce(infos, empty_info(), fn info, result ->
      %{
        result
        | pending: result.pending + info.pending,
          working: result.working + info.working,
          processed: result.processed + info.processed,
          failed: result.failed + info.failed
      }
    end)
  end

  defp empty_info, do: %{pending: 0, working: 0, processed: 0, failed: 0, queues: 0}
end
