defmodule Rex.QueueTest do
  use ExUnit.Case

  alias Rex.Queue

  describe "enqueue/2" do
    test "enqueues an item" do
      queue = Queue.new
      assert Queue.size(queue) == 0
      assert {:ok, queue} = Queue.enqueue(queue, 1)
      assert Queue.size(queue) == 1
    end
  end

  describe "dequeue/1" do
    test "removes first item enqueued" do
      queue = Queue.new
      {:ok, queue} = Queue.enqueue(queue, 1)
      {:ok, queue} = Queue.enqueue(queue, 2)
      assert {:ok, queue, 1} = Queue.dequeue(queue)
      assert {:ok, _queue, 2} = Queue.dequeue(queue)
    end

    test "returns error if queue is empty" do
      queue = Queue.new
      assert {:error, :empty} = Queue.dequeue(queue)
    end
  end

  describe "to_list/1" do
    test "returns a list of the currently queued items" do
      queue = Queue.new
      {:ok, queue} = Queue.enqueue(queue, 1)
      {:ok, queue} = Queue.enqueue(queue, 2)
      list = Queue.to_list(queue)
      assert ^list = [1, 2]
    end

    test "returns an empty list when the queue is empty" do
      queue = Queue.new
      list = Queue.to_list(queue)
      assert list = []
    end
  end

  describe "from_list/1" do
    test "returns a new %Queue{} from the list" do
      queue = Queue.from_list([1, 2])
      assert {:ok, queue, 1} = Queue.dequeue(queue)
      assert {:ok, _queue, 2} = Queue.dequeue(queue)
    end

    test "returns an empty %Queue{} from an empty list" do
      queue = Queue.from_list([])
      assert {:error, :empty} = Queue.dequeue(queue)
    end
  end
end
