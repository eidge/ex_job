defmodule Rex.Job do
  # We can't define callbacks for functions with an arbitrary number of
  # arguments, so we limit the maximum number of arguments to 5.
  @callback group_by :: String.t
  @callback group_by(any) :: String.t
  @callback group_by(any, any) :: String.t
  @callback group_by(any, any, any) :: String.t
  @callback group_by(any, any, any, any) :: String.t
  @callback group_by(any, any, any, any, any) :: String.t

  @callback perform :: String.t
  @callback perform(any) :: String.t
  @callback perform(any, any) :: String.t
  @callback perform(any, any, any) :: String.t
  @callback perform(any, any, any, any) :: String.t
  @callback perform(any, any, any, any, any) :: String.t

  alias Rex.QueueManager.{Dispatcher, GroupDispatcher}

  defstruct [:module, :arguments, :dispatcher, :queue_name]

  def new(job_module, args) do
    group_by = apply(job_module, :group_by, args)
    queue_name = queue_name(job_module, group_by)
    dispatcher = dispatcher(group_by)
    struct!(
      __MODULE__,
      module: job_module,
      arguments: args,
      dispatcher: dispatcher,
      queue_name: queue_name
    )
  end

  defp queue_name(job_module, nil), do: to_string(job_module)
  defp queue_name(job_module, group_by), do: "#{job_module}-#{group_by}"

  defp dispatcher(nil), do: Dispatcher
  defp dispatcher(_), do: GroupDispatcher

  defmacro __using__(_opts \\ []) do
    quote do
      @behaviour Rex.Job

      def group_by, do: nil
      def group_by(_1), do: nil
      def group_by(_1, _2), do: nil
      def group_by(_1, _2, _3), do: nil
      def group_by(_1, _2, _3, _4), do: nil
      def group_by(_1, _2, _3, _4, _5), do: nil

      def perform, do: throw("perform/0 was not implemented")
      def perform(_1), do: throw("perform/1 was not implemented")
      def perform(_1, _2), do: throw("perform/2 was not implemented")
      def perform(_1, _2, _3), do: throw("perform/3 was not implemented")
      def perform(_1, _2, _3, _4), do: throw("perform/4 was not implemented")
      def perform(_1, _2, _3, _4, _5), do: throw("perform/5 was not implemented")

      defoverridable Rex.Job
    end
  end
end
