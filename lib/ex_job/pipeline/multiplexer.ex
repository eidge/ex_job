defmodule ExJob.Pipeline.Multiplexer do
  @moduledoc false

  use ConsumerSupervisor

  alias ExJob.Pipeline.Sink

  def start_link(args), do: ConsumerSupervisor.start_link(__MODULE__, args, [])

  def init(job_module: job_module, subscribe_to: [source]) do
    children = children(source)
    opts = options(source, job_module)
    ConsumerSupervisor.init(children, opts)
  end

  defp children(source) do
    [%{id: Sink, start: {Sink, :start_link, [source]}, restart: :temporary}]
  end

  defp options(source, job_module) do
    [
      strategy: :one_for_one,
      subscribe_to: [{source, max_demand: job_module.concurrency(), min_demand: 0}]
    ]
  end
end
