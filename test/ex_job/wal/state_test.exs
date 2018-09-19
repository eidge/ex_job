defmodule ExJob.WAL.StateTest do
  use ExUnit.Case

  alias ExJob.WAL.{State, InMemoryFile}

  @path "some_in_memory_path"

  describe "restore_or_create/2" do
    test "Creates new state file" do
      {:ok, state} = State.restore_or_create(@path, file_mod: InMemoryFile)
      assert state.state_file
      assert state.current_file
      assert state.wal_pointer == 1
      assert InMemoryFile.read(state.state_file) == {:ok, [%{wal_pointer: 1}]}
    end

    test "Restores state from file" do
      # Need to be able to pass a file (in-memory file-system for instance) to
      # the restore_or_create/2 function to test this
    end
  end

  describe "compact/2" do
    setup do
      {:ok, state} = State.restore_or_create(@path, file_mod: InMemoryFile)
      {:ok, state: state}
    end

    test "Creates new wal file", ctx do
      initial_wal = ctx.state.current_file
      {:ok, new_state} = State.compact(ctx.state, "initial_state")
      assert initial_wal != new_state.current_file
      assert new_state.wal_pointer == 2
    end

    test "Creates successive files correctly", ctx do
      assert InMemoryFile.path(ctx.state.current_file) == "#{@path}/wal.1.ex_job"
      assert ctx.state.wal_pointer == 1

      {:ok, state2} = State.compact(ctx.state, "ignore")
      assert InMemoryFile.path(state2.current_file) == "#{@path}/wal.2.ex_job"
      assert state2.wal_pointer == 2

      {:ok, state3} = State.compact(state2, "ignore")
      assert InMemoryFile.path(state3.current_file) == "#{@path}/wal.3.ex_job"
      assert state3.wal_pointer == 3
    end

    test "Truncates and closes old file", ctx do
      initial_wal = ctx.state.current_file
      InMemoryFile.append(ctx.state.current_file, "some state")

      {:ok, _} = State.compact(ctx.state, "initial_state")
      {:ok, old_contents} = InMemoryFile.read_closed(initial_wal)

      assert old_contents == []
    end

    test "Writes snapshot content to the new WAL", ctx do
      {:ok, new_state} = State.compact(ctx.state, "initial_state")
      {:ok, [snapshot]} = InMemoryFile.read(new_state.current_file)
      assert snapshot == "initial_state"
    end

    test "Updates state file correctly", ctx do
      state_file = ctx.state.state_file
      {:ok, state} = State.compact(ctx.state, "ignore")
      {:ok, _} = State.compact(state, "ignore")

      {:ok, state_contents} = InMemoryFile.read(state_file)
      assert Enum.count(state_contents) == 3
      assert state_contents == [
        %{wal_pointer: 1},
        %{wal_pointer: 2},
        %{wal_pointer: 3},
      ]
    end
  end
end
