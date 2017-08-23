defmodule Rex do
  @moduledoc """
  Documentation for Rex.
  """

  @doc """
  Enqueues a job that will be processed by **job_module** with **args**
  passed to it.
  """
  def enqueue(_job_module, _args \\ []) do
    :ok
  end
end
