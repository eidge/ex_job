defmodule ExJob.Queue do
  @moduledoc false

  @enforce_keys [:queue]
  defstruct [:queue]

  def new do
    %__MODULE__{queue: :queue.new}
  end

  def enqueue(state = %__MODULE__{}, elm) do
    queue = :queue.in(elm, state.queue)
    {:ok, %__MODULE__{state | queue: queue}}
  end

  def dequeue(state = %__MODULE__{}) do
    case :queue.out(state.queue) do
      {:empty, _queue} -> {:error, :empty}
      {{_value, item}, queue} -> {:ok, %__MODULE__{state | queue: queue}, item}
    end
  end

  def size(state = %__MODULE__{}) do
    :queue.len(state.queue)
  end

  def to_list(state = %__MODULE__{}) do
    :queue.to_list(state.queue)
  end

  def from_list(list) when is_list(list) do
    queue = :queue.from_list(list)
    %__MODULE__{queue: queue}
  end
end
