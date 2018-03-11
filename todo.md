# TODO

- Job features
  - Implement Job.uniq_by/n, if this method is present, than there should be at
    most one pending job for that key ever (think subscribed services).
    We might want to implement this along with the group_by feature.
    Something like:
      group_by(key), do: key
      uniq, do: true

- Add a way to import jobs from redis (sidekiq, resque, etc), probably in a
  different mix package.

- Refactor:
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
  - Start pipelines automatically based off of meta-programming

- Support distributed workers
  - First thought is implement a leader + followers
  - Raft or similar for leader election
  - Do we want to optimize for speed or safety?
    - I.E.- Strong or eventual consistency?
    - Eventual consistency prevents us from guarantying at least once delivery
      if a node fails.
    - Strong consistency might be too slow, specially if clusters are located in
      different zones.
