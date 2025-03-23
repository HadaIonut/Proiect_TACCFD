defmodule Member do
  @part_size 1024

  def start(authority_pid) do
    pid = spawn_link(fn -> loop(%{authority_pid: authority_pid}) end)

    send(authority_pid, {:add_member, pid})
    pid
  end

  def register_file(authority_pid, self_pid, file_id, file_path) do
    name = String.split(file_path, "/") |> List.last()

    parts_count =
      File.stream!(file_path)
      |> Stream.chunk_every(@part_size)
      |> Enum.reduce(0, fn cur, acc ->
        File.write!("./data/parts/#{name}_part_#{acc}", cur)
        acc + 1
      end)

    IO.inspect(parts_count)

    send(authority_pid, {:register_file, file_id, parts_count, self_pid})
    send(self_pid, {:register_file, file_id, name, parts_count})
  end

  defp downloads_reducer(file_id) do
    fn %{parts_available: parts, seeder_pid: seeder}, [rec_parts, rec_data] ->
      res = Enum.find(parts, nil, fn elem -> !Enum.member?(rec_parts, elem) end)

      if res != nil do
        send(seeder, {:get_file_part, file_id, res, self()})

        rec_data =
          receive do
            {:data, _file_id, part_index, data} ->
              file_location = "./data/recv_parts/#{file_id}_part_#{part_index}"
              File.write!(file_location, data)
              [%{index: part_index, file_location: file_location}] ++ rec_data
          end

        [[res] ++ rec_parts, rec_data]
      else
        [rec_parts, rec_data]
      end
    end
  end

  defp download_manager(
         authority_pid,
         parent_pid,
         file_id,
         %{parts_count: parts_count, seeders: seeders},
         [parts, data]
       ) do
    [parts, data] =
      Enum.reduce(seeders, [parts, data], downloads_reducer(file_id))

    parts = parts |> Enum.sort()

    send(authority_pid, {:join_as_seeder, file_id, parts, parent_pid})

    if length(parts) < parts_count do
      IO.inspect("not enough parts")

      download_manager(
        authority_pid,
        parent_pid,
        file_id,
        %{parts_count: parts_count, seeders: seeders},
        [parts, data]
      )
    else
      {:ok, output_file} = File.open(file_id, [:write])

      try do
        Enum.sort(data, &(Map.get(&1, :index) < Map.get(&2, :index)))
        |> Enum.each(fn file_info ->
          File.stream!(Map.get(file_info, :file_location), [])
          |> Enum.each(fn chunk ->
            IO.binwrite(output_file, chunk)
          end)
        end)
      after
        File.close(output_file)
      end
    end
  end

  defp loop(state) do
    receive do
      {:register_file, file_id, file_name, file_parts} ->
        entry = %{file_id: file_id, file_name: file_name, parts: file_parts}

        Map.update(state, :files, Map.put(%{}, file_id, entry), fn old ->
          Map.put(old, file_id, entry)
        end)
        |> IO.inspect()
        |> loop()

      {:download_file, file_id} ->
        send(Map.get(state, :authority_pid), {:get_file_info, file_id, self()})
        loop(state)

      {:file_info, file_id, file_info} ->
        spawn_link(fn ->
          download_manager(Map.get(state, :authority_pid), self(), file_id, file_info, [[], []])
        end)

        loop(state)

      {:files, files} ->
        IO.inspect(files)
        loop(state)

      {:get_file_part, file_id, part_index, callback_pid} ->
        %{file_name: file_name} = get_in(state, [:files, file_id])

        content = File.read!("./data/parts/#{file_name}_part_#{part_index}")

        send(callback_pid, {:data, file_id, part_index, content})
        loop(state)

      {:close} ->
        IO.inspect("byeee")
    end
  end
end
