wal_path = "benchmarks/wal_files/appending_events"
save_path = "benchmarks/wal_appending_events"

alias ExJob.WAL
alias ExJob.WAL.Events

before_fn = fn events ->
  {:ok, pid} = WAL.start_link(wal_path, name: nil)
  {events, pid}
end

after_fn = fn {_, pid} ->
  GenServer.stop(pid)
  File.rm_rf!(wal_path)
end

options = [
  before_scenario: before_fn,
  after_scenario: after_fn,
  inputs: %{
    "1 event": [Events.QueueSnapshot.new(:some_job, :some_state)],
    "1000 events": Enum.map(1..1000, fn _ -> Events.QueueSnapshot.new(:some_job, :some_state) end),
    "10000 events": Enum.map(1..10000, fn _ -> Events.QueueSnapshot.new(:some_job, :some_state) end),
  },
  load: save_path,
]

options = if match?(["--save"], System.argv) do
  options ++ [ save: [path: save_path, tag: "master"]]
else
  options
end

benchmark = %{
  "Appending events": fn ({events, wal}) ->
    Enum.each(events, fn e -> WAL.append(wal, e) end)
  end
}

Benchee.run(benchmark, options)
