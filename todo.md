# TODO

- QueueManager needs a refactor
  - We're using queues in places where we should be using maps to allow faster
    dequeueing and success/failure reports.

- Runners are being kept alive for ever (check GroupDispatcher)

- Job features
  - Implement Job.uniq_by/n, if this method is present, than there should be at
    most one pending job for that key ever (think subscribed services).
    We might want to implement this along with the group_by feature.
    Something like:
      group_by(key), do: key
      uniq, do: true

  - Add concurrency limit (poolboy?, register?) both global and per job.

- Add a way to import jobs from redis (sidekiq, resque, etc), probably in a
  different mix package.
