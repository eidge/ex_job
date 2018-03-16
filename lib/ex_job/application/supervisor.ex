defmodule ExJob.Application.Supervisor do
  use Supervisor

  alias ExJob.{Central, WAL}

  def start_link(_args \\ []) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(nil) do
    Supervisor.init(children(), strategy: :one_for_one)
  end

  defp children do
    [
      {WAL, wal_path()},
      {Central, name: Central},
    ]
  end

  defp wal_path, do: Application.get_env(:ex_job, :wal_path, ".ex_job.wal")
end
