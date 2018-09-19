defmodule ExJob.WAL.State do
  defstruct [:path, :file_mod, :state_file, :current_file, wal_pointer: 0]

  @doc """
  Restore WAL state from existing in-disk data or initialize and store new state.
  """
  def restore_or_create(path, file_mod: file_mod) do
    ensure_directory_exists!(path)

    build_state(path, file_mod)
    |> open_state_file!
    |> maybe_restore_state
  end

  defp ensure_directory_exists!(path) do
    :ok = File.mkdir_p(path)
  end

  defp build_state(path, file_mod) when is_binary(path) do
    %__MODULE__{path: path, file_mod: file_mod}
  end

  defp open_state_file!(state) do
    {:ok, file} =
      state
      |> state_filename
      |> state.file_mod.open

    %{state | state_file: file}
  end

  defp maybe_restore_state(state) do
    {:ok, states} = state.file_mod.read(state.state_file)

    case List.last(states) do
      nil ->
        state =
          state
          |> open_new_wal!
          |> write_state!

        {:ok, state}

      serialized_state ->
        restored_state = deserialize(state, serialized_state)
        {:ok, restored_state}
    end
  end

  defp open_new_wal!(state) do
    state
    |> increment_wal_pointer
    |> open_wal!
    |> truncate_wal!
  end

  defp increment_wal_pointer(state) do
    %{state | wal_pointer: state.wal_pointer + 1}
  end

  defp open_wal!(state) do
    {:ok, file} = state |> wal_filename |> state.file_mod.open
    %{state | current_file: file}
  end

  defp deserialize(state, serialized) do
    state
    |> Map.merge(serialized)
    |> open_wal!
  end

  defp state_filename(state), do: Path.join(state.path, "state.ex_job")
  defp wal_filename(state), do: Path.join(state.path, "wal.#{state.wal_pointer}.ex_job")

  @doc """
  Compact WAL file by replacing all events with a state snapshot
  """
  def compact(old_state, snapshot) do
    new_state =
      open_new_wal!(old_state)
      |> append!(snapshot)
      |> write_state!

    delete_wal!(old_state)

    {:ok, new_state}
  end

  defp truncate_wal!(state) do
    :ok = state.file_mod.truncate(state.current_file)
    state
  end

  defp append!(state, event) do
    :ok = state.file_mod.append(state.current_file, event)
    state
  end

  defp write_state!(state) do
    serialized_state = serialize(state)
    :ok = state.file_mod.append(state.state_file, serialized_state)
    state
  end

  defp serialize(state) do
    %{wal_pointer: state.wal_pointer}
  end

  defp delete_wal!(state) do
    truncate_wal!(state)
    :ok = state.file_mod.close(state.current_file)
    state
  end
end
