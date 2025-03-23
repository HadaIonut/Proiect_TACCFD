defmodule ActorGraph do
  def start do
    graph = :digraph.new()
    labels = %{}

    parent = self()
    labels = Map.put(labels, parent, "Main")

    IO.puts("Main process: #{inspect(parent)}")

    {p1, labels} = track_spawn(fn -> work() end, parent, graph, labels, "Worker 1")
    {p2, labels} = track_spawn(fn -> work() end, parent, graph, labels, "Worker 2")
    {p3, labels} = track_spawn(fn -> work() end, p1, graph, labels, "Worker 3")
    {p4, labels} = track_spawn(fn -> work() end, p2, graph, labels, "Worker 4")

    Process.sleep(500)

    export_dot("actor_graph.dot", graph, labels)

    :digraph.delete(graph)
  end

  defp work do
    Process.sleep(:rand.uniform(1000))
  end

  defp track_spawn(fun, parent, graph, labels, label) do
    pid = spawn(fun)
    add_link(parent, pid, graph)

    labels = Map.put(labels, pid, label)
    {pid, labels}
  end

  defp add_link(parent, child, graph) do
    :digraph.add_vertex(graph, parent)
    :digraph.add_vertex(graph, child)
    :digraph.add_edge(graph, parent, child)
  end

  defp export_dot(filename, graph, labels) do
    File.write!(filename, to_dot(graph, labels))
    IO.puts("Graph saved as #{filename}")
  end

  defp to_dot(graph, labels) do
    vertices = :digraph.vertices(graph)
    edges = :digraph.edges(graph)

    vertex_lines =
      vertices
      |> Enum.map(fn pid ->
        label = Map.get(labels, pid, inspect(pid))
        "  \"#{inspect(pid)}\" [label=\"#{label}\"];"
      end)
      |> Enum.join("\n")

    edge_lines =
      edges
      |> Enum.map(fn e ->
        {_, from, to, _} = :digraph.edge(graph, e)
        "  \"#{inspect(from)}\" -> \"#{inspect(to)}\";"
      end)
      |> Enum.join("\n")

    """
    digraph ActorGraph {
    #{vertex_lines}
    #{edge_lines}
    }
    """
  end
end
