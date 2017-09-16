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
