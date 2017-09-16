# TODO

- Queue manager should not be calling the dispatcher.
  - This will make it faster and hence capable of enqueueing more jobs per
    second.
  - And it will also make it simpler, leading to a smaller chance of it
    crashing.
  - Dispatcher -> Build Job Struct
               -> QueueManager.enqueue
               -> dispatch(strategy: Synchronous | Parallel)

- QueueManager needs a refactor

- Rather than pass tuples everywhere we need a struct to old the job
  information, this will make it easier to refactor and change what data we need
  to enqueue/dequeue jobs.
- Current Rex.Job defines functions with up to 5 arguments, besides this being a
  total hack, it makes it harder to debug as we won't be able to rely on the
  compiler to find undefined function calls. We are instead relying on a runtime
  exception.
