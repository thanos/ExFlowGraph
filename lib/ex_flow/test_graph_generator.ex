defmodule ExFlow.TestGraphGenerator do
  @moduledoc """
  Generates test graphs with configurable sizes for performance testing.
  """

  alias ExFlow.Core.Graph, as: FlowGraph

  @doc """
  Generates a graph with the specified number of nodes and edges.

  ## Options
  - `:node_count` - Number of nodes to generate (default: 100)
  - `:edge_density` - Average edges per node (default: 2.0)
  - `:layout` - Layout strategy (:grid, :random, :circular) (default: :grid)
  """
  def generate(opts \\ []) do
    node_count = Keyword.get(opts, :node_count, 100)
    edge_density = Keyword.get(opts, :edge_density, 2.0)
    layout = Keyword.get(opts, :layout, :grid)

    graph = FlowGraph.new()

    # Generate nodes
    {graph, node_ids} = generate_nodes(graph, node_count, layout)

    # Generate edges
    graph = generate_edges(graph, node_ids, edge_density)

    {:ok, graph}
  end

  defp generate_nodes(graph, count, layout) do
    positions = calculate_positions(count, layout)

    {graph, node_ids} =
      Enum.reduce(1..count, {graph, []}, fn i, {acc_graph, ids} ->
        node_id = "node-#{i}"
        node_type = if rem(i, 2) == 0, do: :task, else: :agent
        position = Enum.at(positions, i - 1)

        case FlowGraph.add_node(acc_graph, node_id, node_type, %{position: position}) do
          {:ok, new_graph} -> {new_graph, [node_id | ids]}
          {:error, _} -> {acc_graph, ids}
        end
      end)

    {graph, Enum.reverse(node_ids)}
  end

  defp calculate_positions(count, :grid) do
    # Grid layout with ~20 nodes per row
    cols = ceil(:math.sqrt(count * 1.5))
    spacing_x = 200
    spacing_y = 150

    for i <- 0..(count - 1) do
      row = div(i, cols)
      col = rem(i, cols)
      %{x: col * spacing_x + 100, y: row * spacing_y + 100}
    end
  end

  defp calculate_positions(count, :random) do
    # Random positions in a 4000x3000 area
    for _ <- 1..count do
      %{x: :rand.uniform(4000), y: :rand.uniform(3000)}
    end
  end

  defp calculate_positions(count, :circular) do
    # Circular layout
    radius = count * 5
    center_x = 2000
    center_y = 1500

    for i <- 0..(count - 1) do
      angle = 2 * :math.pi() * i / count

      %{
        x: round(center_x + radius * :math.cos(angle)),
        y: round(center_y + radius * :math.sin(angle))
      }
    end
  end

  defp generate_edges(graph, node_ids, edge_density) do
    target_edge_count = round(length(node_ids) * edge_density)

    # Create edges by connecting each node to a few random other nodes
    Enum.reduce(1..target_edge_count, graph, fn i, acc_graph ->
      source = Enum.random(node_ids)
      target = Enum.random(node_ids)

      # Don't create self-loops
      if source != target do
        edge_id = "edge-#{i}"

        case FlowGraph.add_edge(acc_graph, edge_id, source, "out", target, "in") do
          {:ok, new_graph} -> new_graph
          {:error, _} -> acc_graph
        end
      else
        acc_graph
      end
    end)
  end

  @doc """
  Generates a stress test graph with many nodes and edges.
  """
  def stress_test_graph do
    generate(node_count: 500, edge_density: 3.0, layout: :grid)
  end

  @doc """
  Generates a large graph for performance testing.
  """
  def large_graph do
    generate(node_count: 1000, edge_density: 2.5, layout: :grid)
  end

  @doc """
  Generates a small test graph for quick testing.
  """
  def small_graph do
    generate(node_count: 50, edge_density: 2.0, layout: :grid)
  end
end
