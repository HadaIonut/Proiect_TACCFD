defmodule BitTorrentTest do
  use ExUnit.Case, async: true

  test "register files" do
    authority_pid = Authority.start()
    member_pid = Member.start(authority_pid)

    Member.register_file(authority_pid, member_pid, "123", "./testInput.txt")

    send(authority_pid, {:get_files, self()})

    receive do
      {:files, files} ->
        IO.inspect(files)
        assert Map.keys(files) |> length() == 1
        seeders = Map.get(files, "123") |> Map.get(:seeders)
        assert seeders |> length() == 1
    end

    send(authority_pid, {:close})
    send(member_pid, {:close})
  end

  test "add member to the seed list" do
    authority_pid = Authority.start()
    member_pid = Member.start(authority_pid)
    member_pid_2 = Member.start(authority_pid)

    member_pid_list = [member_pid, member_pid_2]
    IO.inspect(member_pid_list)

    Member.register_file(authority_pid, member_pid, "123", "./testInput.txt")

    send(member_pid_2, {:download_file, "123"})

    Process.sleep(100)

    send(authority_pid, {:get_file_info, "123", self()})

    receive do
      {:file_info, file_id, %{seeders: seeders}} ->
        assert length(seeders) == 2

        Enum.each(seeders, fn %{parts_available: parts, seeder_pid: pid} ->
          pid in member_pid_list
        end)
    end
  end
end
