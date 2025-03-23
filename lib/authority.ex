defmodule Authority do
  def start() do
    spawn_link(fn -> loop(%{}) end)
  end

  defp loop(state) do
    receive do
      {:add_member, member_pid} ->
        Map.update(state, :members, [member_pid], fn old ->
          [member_pid] ++ old
        end)
        |> loop()

      {:print_members} ->
        Map.get(state, :members)
        |> IO.inspect()

        loop(state)

      {:print_files} ->
        Map.get(state, :files)
        |> IO.inspect()

        loop(state)

      {:register_file, file_id, parts_count, seed} ->
        entry = %{
          parts_count: parts_count,
          seeders: [
            %{seeder_pid: seed, parts_available: Enum.to_list(0..(parts_count - 1))}
          ]
        }

        Map.update(
          state,
          :files,
          Map.put(%{}, file_id, entry),
          fn old ->
            Map.put(old, file_id, entry)
          end
        )
        |> loop()

      {:get_files, callback_pid} ->
        files = Map.get(state, :files)
        send(callback_pid, {:files, files})
        loop(state)

      {:get_file_info, file_id, callback_pid} ->
        file_info = Map.get(state, :files) |> Map.get(file_id)

        send(callback_pid, {:file_info, file_id, file_info})
        loop(state)

      {:join_as_seeder, file_id, parts, callback_pid} ->
        update_in(state, [:files, file_id, :seeders], fn old_seeders ->
          new_value = %{seeder_pid: callback_pid, parts_available: parts}

          case Enum.find_index(old_seeders, fn %{seeder_pid: pid} -> pid == callback_pid end) do
            nil ->
              [new_value] ++ old_seeders

            index ->
              List.replace_at(old_seeders, index, new_value)
          end
        end)
        |> loop()

      {:close} ->
        IO.inspect("byeee")
    end
  end
end
