require Logger
Logger.configure(level: :warn)

defmodule AckJob do
  use ExJob.Job

  def perform(pid) do
    send pid, :ping
    :ok
  end
end

alias ExJob.WAL

before_fn = fn wal_path ->
  {:ok, pid} = WAL.start_link(wal_path, name: nil)
  pid
end

after_fn = fn pid ->
  GenServer.stop(pid)
end


save_path = "benchmarks/wal_reading_events"
options = [
  after_scenario: after_fn,
  load: save_path,
]

options = if match?(["--save"], System.argv) do
  options ++ [ save: [path: save_path, tag: "master"]]
else
  options
end

benchmark = %{
  "Reading WAL from events (all jobs completed)": {
    fn wal -> WAL.read(wal, AckJob) end,
    before_scenario: fn _ -> before_fn.("benchmarks/wal_files/100_000_completed_jobs") end,
  },
  "Reading WAL from snapshot (all jobs completed)": {
    fn wal -> WAL.read(wal, AckJob) end,
    before_scenario: fn _ -> before_fn.("benchmarks/wal_files/100_000_completed_jobs_snapshots") end,
  },
  "Reading WAL from events (all jobs pending)": {
    fn wal -> WAL.read(wal, AckJob) end,
    before_scenario: fn _ -> before_fn.("benchmarks/wal_files/100_000_pending_jobs") end,
  },
  "Reading WAL from snapshot (all jobs pending)": {
    fn wal -> WAL.read(wal, AckJob) end,
    before_scenario: fn _ -> before_fn.("benchmarks/wal_files/100_000_pending_jobs_snapshots") end,
  },
}

Benchee.run(benchmark, options)
