# TODO

- QueueManager needs a refactor
  - We're using queues in places where we should be using maps to allow faster
    dequeueing and success/failure reports.

- Passing Rex.enqueue/2 a second argument that is not a list should throw an
  helpful exception rather than blow up with 'argument error'.

- Current Rex.Job defines functions with up to 5 arguments, besides this being a
  total hack, it makes it harder to debug as we won't be able to rely on the
  compiler to find undefined function calls. We are instead relying on a runtime
  exception.

- Get rid of the String.to_atom currently being used in GroupDispatcher. We
  should use a Registry or a Process Pool to handle that.

- Runner should always be supervised.
