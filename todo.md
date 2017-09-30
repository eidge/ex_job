# TODO

- QueueManager needs a refactor
  - We're using queues in places where we should be using maps to allow faster
    dequeueing and success/failure reports.

- Get rid of the String.to_atom currently being used in GroupDispatcher. We
  should use a Registry or a Process Pool to handle that.

- Dispatcher is leaving zombie processes behind. It always starts a runner, and
  runners wait indefinitely for more jobs.

- Runner should always be supervised.

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
