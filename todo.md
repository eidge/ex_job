# TODO

- QueueManager needs a refactor

- Current Rex.Job defines functions with up to 5 arguments, besides this being a
  total hack, it makes it harder to debug as we won't be able to rely on the
  compiler to find undefined function calls. We are instead relying on a runtime
  exception.

- Get rid of the String.to_atom currently being used in GroupDispatcher. We
  should use a Registry or a Process Pool to handle that.
