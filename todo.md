# TODO

- QueueManager needs a refactor
  - We're using queues in places where we should be using maps to allow faster
    dequeueing and success/failure reports.

- Get rid of the String.to_atom currently being used in GroupDispatcher. We
  should use a Registry or a Process Pool to handle that.

- Runner should always be supervised.
