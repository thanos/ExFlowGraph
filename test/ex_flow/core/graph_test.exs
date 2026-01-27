defmodule ExFlow.Core.GraphTest do
  use ExUnit.Case, async: true

  alias ExFlow.Core.Graph

  describe "new/0" do
    test "creates an empty graph" do
      graph = Graph.new()
      assert Graph.get_nodes(graph) == []
      assert Graph.get_edges(graph) == []
    end
  end

  describe "add_node/4" do
    test "adds a valid node to the graph" do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 100, y: 200}})

      {:ok, node} = Graph.get_node(graph, "node-1")
      assert node.id == "node-1"
      assert node.type == :agent
      assert node.position == %{x: 100, y: 200}
      assert node.metadata == %{}
    end

    test "adds node with default position when not provided" do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "node-1", :task)

      {:ok, node} = Graph.get_node(graph, "node-1")
      assert node.position == %{x: 0, y: 0}
    end

    test "adds node with custom metadata" do
      graph = Graph.new()

      {:ok, graph} =
        Graph.add_node(graph, "node-1", :agent, %{
          position: %{x: 50, y: 75},
          metadata: %{color: "blue", size: "large"}
        })

      {:ok, node} = Graph.get_node(graph, "node-1")
      assert node.metadata.color == "blue"
      assert node.metadata.size == "large"
    end

    test "validates node schema" do
      node = %{id: "test", type: :invalid, position: %{x: "not_a_number", y: 0}, metadata: %{}}
      assert Graph.validate_node(node) == {:error, :invalid_node_schema}
    end
  end

  describe "add_edge/6" do
    setup do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 0, y: 0}})
      {:ok, graph} = Graph.add_node(graph, "node-2", :task, %{position: %{x: 100, y: 100}})
      %{graph: graph}
    end

    test "adds a valid edge between nodes", %{graph: graph} do
      {:ok, graph} = Graph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in")

      edges = Graph.get_edges(graph)
      assert length(edges) == 1

      edge = hd(edges)
      assert edge.id == "edge-1"
      assert edge.source == "node-1"
      assert edge.source_handle == "out"
      assert edge.target == "node-2"
      assert edge.target_handle == "in"
    end

    test "returns error when source node doesn't exist", %{graph: graph} do
      result = Graph.add_edge(graph, "edge-1", "nonexistent", "out", "node-2", "in")
      assert result == {:error, :source_not_found}
    end

    test "returns error when target node doesn't exist", %{graph: graph} do
      result = Graph.add_edge(graph, "edge-1", "node-1", "out", "nonexistent", "in")
      assert result == {:error, :target_not_found}
    end

    test "validates edge schema" do
      edge = %{id: "e1", source: "s", source_handle: 123, target: "t", target_handle: "th"}
      assert Graph.validate_edge(edge) == {:error, :invalid_edge_schema}
    end
  end

  describe "update_node_position/3" do
    test "updates node position successfully" do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 0, y: 0}})

      {:ok, graph} = Graph.update_node_position(graph, "node-1", %{x: 150, y: 250})

      {:ok, node} = Graph.get_node(graph, "node-1")
      assert node.position == %{x: 150, y: 250}
    end

    test "returns error for nonexistent node" do
      graph = Graph.new()
      result = Graph.update_node_position(graph, "nonexistent", %{x: 100, y: 100})
      assert result == {:error, :node_not_found}
    end

    test "preserves other node properties" do
      graph = Graph.new()

      {:ok, graph} =
        Graph.add_node(graph, "node-1", :agent, %{
          position: %{x: 0, y: 0},
          metadata: %{color: "red"}
        })

      {:ok, graph} = Graph.update_node_position(graph, "node-1", %{x: 100, y: 200})

      {:ok, node} = Graph.get_node(graph, "node-1")
      assert node.type == :agent
      assert node.metadata == %{color: "red"}
    end
  end

  describe "delete_node/2" do
    test "deletes an existing node" do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 0, y: 0}})

      {:ok, graph} = Graph.delete_node(graph, "node-1")

      assert Graph.get_node(graph, "node-1") == {:error, :node_not_found}
      assert Graph.get_nodes(graph) == []
    end

    test "deletes node and its connected edges" do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 0, y: 0}})
      {:ok, graph} = Graph.add_node(graph, "node-2", :task, %{position: %{x: 100, y: 100}})
      {:ok, graph} = Graph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in")

      {:ok, graph} = Graph.delete_node(graph, "node-1")

      assert Graph.get_edges(graph) == []
    end

    test "returns error for nonexistent node" do
      graph = Graph.new()
      result = Graph.delete_node(graph, "nonexistent")
      assert result == {:error, :node_not_found}
    end
  end

  describe "delete_edge/2" do
    test "deletes an existing edge" do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 0, y: 0}})
      {:ok, graph} = Graph.add_node(graph, "node-2", :task, %{position: %{x: 100, y: 100}})
      {:ok, graph} = Graph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in")

      {:ok, graph} = Graph.delete_edge(graph, "edge-1")

      assert Graph.get_edges(graph) == []
    end

    test "returns error for nonexistent edge" do
      graph = Graph.new()
      result = Graph.delete_edge(graph, "nonexistent")
      assert result == {:error, :edge_not_found}
    end
  end

  describe "get_nodes/1 and get_edges/1" do
    test "returns all nodes in the graph" do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 0, y: 0}})
      {:ok, graph} = Graph.add_node(graph, "node-2", :task, %{position: %{x: 100, y: 100}})

      nodes = Graph.get_nodes(graph)
      assert length(nodes) == 2
      assert Enum.any?(nodes, fn n -> n.id == "node-1" end)
      assert Enum.any?(nodes, fn n -> n.id == "node-2" end)
    end

    test "returns all edges in the graph" do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 0, y: 0}})
      {:ok, graph} = Graph.add_node(graph, "node-2", :task, %{position: %{x: 100, y: 100}})
      {:ok, graph} = Graph.add_node(graph, "node-3", :task, %{position: %{x: 200, y: 200}})
      {:ok, graph} = Graph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in")
      {:ok, graph} = Graph.add_edge(graph, "edge-2", "node-2", "out", "node-3", "in")

      edges = Graph.get_edges(graph)
      assert length(edges) == 2
      assert Enum.any?(edges, fn e -> e.id == "edge-1" end)
      assert Enum.any?(edges, fn e -> e.id == "edge-2" end)
    end
  end

  describe "serialization: to_map/1 and from_map/1" do
    test "serializes graph to map" do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 50, y: 75}})
      {:ok, graph} = Graph.add_node(graph, "node-2", :task, %{position: %{x: 150, y: 175}})
      {:ok, graph} = Graph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in")

      map = Graph.to_map(graph)

      assert is_map(map)
      assert length(map.nodes) == 2
      assert length(map.edges) == 1
    end

    test "deserializes map to graph" do
      map = %{
        nodes: [
          %{id: "node-1", type: :agent, position: %{x: 50, y: 75}, metadata: %{}},
          %{id: "node-2", type: :task, position: %{x: 150, y: 175}, metadata: %{}}
        ],
        edges: [
          %{
            id: "edge-1",
            source: "node-1",
            source_handle: "out",
            target: "node-2",
            target_handle: "in"
          }
        ]
      }

      {:ok, graph} = Graph.from_map(map)

      nodes = Graph.get_nodes(graph)
      edges = Graph.get_edges(graph)

      assert length(nodes) == 2
      assert length(edges) == 1
    end

    test "round-trip serialization preserves data" do
      graph = Graph.new()

      {:ok, graph} =
        Graph.add_node(graph, "node-1", :agent, %{
          position: %{x: 100, y: 200},
          metadata: %{color: "blue", size: "large"}
        })

      {:ok, graph} = Graph.add_node(graph, "node-2", :task, %{position: %{x: 300, y: 400}})
      {:ok, graph} = Graph.add_edge(graph, "edge-1", "node-1", "output", "node-2", "input")

      map = Graph.to_map(graph)
      {:ok, restored_graph} = Graph.from_map(map)

      original_nodes = Graph.get_nodes(graph) |> Enum.sort_by(& &1.id)
      restored_nodes = Graph.get_nodes(restored_graph) |> Enum.sort_by(& &1.id)

      assert original_nodes == restored_nodes

      original_edges = Graph.get_edges(graph) |> Enum.sort_by(& &1.id)
      restored_edges = Graph.get_edges(restored_graph) |> Enum.sort_by(& &1.id)

      assert original_edges == restored_edges
    end

    test "returns error for invalid map format" do
      result = Graph.from_map(%{invalid: "format"})
      assert result == {:error, :invalid_map_format}
    end

    test "returns error when edge references nonexistent node" do
      map = %{
        nodes: [
          %{id: "node-1", type: :agent, position: %{x: 0, y: 0}, metadata: %{}}
        ],
        edges: [
          %{
            id: "edge-1",
            source: "node-1",
            source_handle: "out",
            target: "nonexistent",
            target_handle: "in"
          }
        ]
      }

      result = Graph.from_map(map)
      assert {:error, :target_not_found} = result
    end
  end

  describe "immutability" do
    test "operations return new graph without mutating original" do
      graph1 = Graph.new()
      {:ok, graph2} = Graph.add_node(graph1, "node-1", :agent, %{position: %{x: 0, y: 0}})

      assert Graph.get_nodes(graph1) == []
      assert length(Graph.get_nodes(graph2)) == 1
    end

    test "position update doesn't mutate original graph" do
      graph = Graph.new()
      {:ok, graph1} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 0, y: 0}})
      {:ok, graph2} = Graph.update_node_position(graph1, "node-1", %{x: 100, y: 100})

      {:ok, node1} = Graph.get_node(graph1, "node-1")
      {:ok, node2} = Graph.get_node(graph2, "node-1")

      assert node1.position == %{x: 0, y: 0}
      assert node2.position == %{x: 100, y: 100}
    end
  end
end
