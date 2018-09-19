# TODO

- Job features
  - Implement Job.uniq_by/n, if this method is present, than there should be at
    most one pending job for that key ever (think subscribed services).
    We might want to implement this along with the group_by feature.
    Something like:
      group_by(key), do: key
      uniq, do: true
  - Job retries
    - Change WAL to retry jobs after reading all events rather than simply
        failing the jobs

- Add a way to import jobs from redis (sidekiq, resque, etc), probably in a
  different mix package.

- Add a way to wait for a job to finish, once we have this, get rid of all the 
:timer.sleep in tests.

- Rotate WAL.State logs

- Refactor:
  - Use a registry to process names rather than dynamically creating atoms
  - GroupedQueue is currently a mess implemented during a spike to make the
    tests pass.
    - Make the code cleaner
    - Measure and improve performance, we have linear time operations all over
      the place, plus probably also putting a lot of pressure on GC.
  - Queue interface should include a way to access process and failed counts so
    that we can implement those differently on different queues (currently it's
    just a field in the struct).
    - Maybe even move the entire queue metrics to it's own structure with
      increment and getter methods?
    - Or implement it by listening to WAL events.
  - Start pipelines automatically based off of meta-programming
  - Implement TestJob in an helper that can be reused in every test to reduce
      duplication.

- WAL
  - Configurable buffer size (0 - consistent, * - prone to inconsistency but
    faster)
  - Allow WAL.File to write asynchronously to the log (via config flag) - this
    gets us another 20/50% improvement in performance, trading for security and
    at least once guarantees.
    - Maybe write append synchronously, but all other events asynchronously?
    - Make the WAL payload smaller
  - Snapshots
    - Run off of memory, when shutting down push a snapshot that includes the
        current state.
  - Reduce each WAL event size by serializing smaller payloads
  - Move to a WAL per Pipeline, rather than one WAL for everything!

- Support distributed workers
  - If we separate the Queue from the Source, then we can have one machine with
    all the queues and separate the worker pipelines to different machines -
    this seems like the most viable option.
  - First thought is implement a leader + followers
  - Raft or similar for leader election
  - Do we want to optimize for speed or safety?
    - I.E.- Strong or eventual consistency?
    - Eventual consistency prevents us from guarantying at least once delivery
      if a node fails.
    - Strong consistency might be too slow, specially if clusters are located in
      different zones.

- Support deploy where the store runs in a separate process, this would help
    deploys so that we don't need to pay the price of doing a snapshot and then
    reloading everything. It would also be the first step in supporting
    distributed workers because we would have the ability to run the store
    separately.
