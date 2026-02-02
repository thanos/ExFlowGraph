defmodule ExFlow.SerializerTest do
  use ExUnit.Case, async: true

  alias ExFlow.Core.Graph
  alias ExFlow.Serializer

  describe "serialize/1" do
    test "serializes an empty graph" do
      graph = Graph.new()
      {:ok, data} = Serializer.serialize(graph)

      assert data.nodes == []
      assert data.edges == []
    end

    test "serializes graph with nodes" do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 100, y: 200}})

      {:ok, graph} =
        Graph.add_node(graph, "node-2", :task, %{
          position: %{x: 300, y: 400},
          label: "Task",
          metadata: %{color: "blue"}
        })

      {:ok, data} = Serializer.serialize(graph)

      assert length(data.nodes) == 2
      assert Enum.any?(data.nodes, fn n -> n.id == "node-1" && n.type == :agent end)
      assert Enum.any?(data.nodes, fn n -> n.id == "node-2" && n.label == "Task" end)
    end

    test "serializes graph with edges" do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 0, y: 0}})
      {:ok, graph} = Graph.add_node(graph, "node-2", :task, %{position: %{x: 100, y: 100}})
      {:ok, graph} = Graph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in")

      {:ok, data} = Serializer.serialize(graph)

      assert length(data.edges) == 1
      edge = hd(data.edges)
      assert edge.id == "edge-1"
      assert edge.source == "node-1"
      assert edge.target == "node-2"
    end

    test "serializes complete graph with nodes and edges" do
      graph = Graph.new()

      {:ok, graph} =
        Graph.add_node(graph, "node-1", :agent, %{
          position: %{x: 0, y: 0},
          label: "Agent",
          metadata: %{status: "active"}
        })

      {:ok, graph} = Graph.add_node(graph, "node-2", :task, %{position: %{x: 100, y: 100}})

      {:ok, graph} =
        Graph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in", %{label: "flow"})

      {:ok, data} = Serializer.serialize(graph)

      assert length(data.nodes) == 2
      assert length(data.edges) == 1
    end
  end

  describe "deserialize/1" do
    test "deserializes data with atom keys" do
      data = %{
        nodes: [
          %{id: "node-1", type: :agent, position: %{x: 100, y: 200}, metadata: %{}}
        ],
        edges: []
      }

      {:ok, graph} = Serializer.deserialize(data)

      nodes = Graph.get_nodes(graph)
      assert length(nodes) == 1
      node = hd(nodes)
      assert node.id == "node-1"
      assert node.type == :agent
      assert node.position == %{x: 100, y: 200}
    end

    test "deserializes data with string keys" do
      data = %{
        "nodes" => [
          %{
            "id" => "node-1",
            "type" => "agent",
            "position" => %{"x" => 100, "y" => 200},
            "metadata" => %{}
          }
        ],
        "edges" => []
      }

      {:ok, graph} = Serializer.deserialize(data)

      nodes = Graph.get_nodes(graph)
      assert length(nodes) == 1
      node = hd(nodes)
      assert node.id == "node-1"
      assert node.type == :agent
      assert node.position == %{x: 100, y: 200}
    end

    test "deserializes data with mixed key types" do
      data = %{
        "nodes" => [
          %{
            "id" => "node-1",
            "type" => "task",
            "position" => %{"x" => 50, "y" => 75},
            "metadata" => %{}
          }
        ],
        "edges" => []
      }

      {:ok, graph} = Serializer.deserialize(data)

      nodes = Graph.get_nodes(graph)
      assert length(nodes) == 1
      node = hd(nodes)
      assert node.id == "node-1"
      assert node.type == :task
      assert node.position == %{x: 50, y: 75}
    end

    test "deserializes empty graph data" do
      data = %{nodes: [], edges: []}

      {:ok, graph} = Serializer.deserialize(data)

      assert Graph.get_nodes(graph) == []
      assert Graph.get_edges(graph) == []
    end

    test "deserializes graph with edges" do
      data = %{
        nodes: [
          %{id: "node-1", type: :agent, position: %{x: 0, y: 0}, metadata: %{}},
          %{id: "node-2", type: :task, position: %{x: 100, y: 100}, metadata: %{}}
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

      {:ok, graph} = Serializer.deserialize(data)

      edges = Graph.get_edges(graph)
      assert length(edges) == 1
      edge = hd(edges)
      assert edge.id == "edge-1"
      assert edge.source == "node-1"
      assert edge.target == "node-2"
    end

    test "deserializes graph with string edge keys" do
      data = %{
        "nodes" => [
          %{
            "id" => "node-1",
            "type" => "agent",
            "position" => %{"x" => 0, "y" => 0},
            "metadata" => %{}
          },
          %{
            "id" => "node-2",
            "type" => "task",
            "position" => %{"x" => 100, "y" => 100},
            "metadata" => %{}
          }
        ],
        "edges" => [
          %{
            "id" => "edge-1",
            "source" => "node-1",
            "source_handle" => "out",
            "target" => "node-2",
            "target_handle" => "in"
          }
        ]
      }

      {:ok, graph} = Serializer.deserialize(data)

      edges = Graph.get_edges(graph)
      assert length(edges) == 1
      edge = hd(edges)
      assert edge.id == "edge-1"
    end

    test "handles missing nodes key" do
      data = %{edges: []}

      {:ok, graph} = Serializer.deserialize(data)

      assert Graph.get_nodes(graph) == []
    end

    test "handles missing edges key" do
      data = %{
        nodes: [
          %{id: "node-1", type: :agent, position: %{x: 0, y: 0}, metadata: %{}}
        ]
      }

      {:ok, graph} = Serializer.deserialize(data)

      assert Graph.get_edges(graph) == []
      assert length(Graph.get_nodes(graph)) == 1
    end

    test "handles missing position with default" do
      data = %{
        nodes: [
          %{id: "node-1", type: :agent, metadata: %{}}
        ],
        edges: []
      }

      {:ok, graph} = Serializer.deserialize(data)

      nodes = Graph.get_nodes(graph)
      node = hd(nodes)
      assert node.position == %{x: 0, y: 0}
    end

    test "handles missing metadata with default" do
      data = %{
        nodes: [
          %{id: "node-1", type: :agent, position: %{x: 0, y: 0}}
        ],
        edges: []
      }

      {:ok, graph} = Serializer.deserialize(data)

      nodes = Graph.get_nodes(graph)
      node = hd(nodes)
      assert node.metadata == %{}
    end

    test "returns error for invalid data" do
      result = Serializer.deserialize("not a map")
      assert result == {:error, :invalid_data}
    end

    test "returns error for nil" do
      result = Serializer.deserialize(nil)
      assert result == {:error, :invalid_data}
    end

    test "handles unknown node type" do
      data = %{
        nodes: [
          %{id: "node-1", type: "nonexistent_type", position: %{x: 0, y: 0}, metadata: %{}}
        ],
        edges: []
      }

      # Should use :unknown as fallback when atomize fails
      assert_raise ArgumentError, fn ->
        Serializer.deserialize(data)
      end
    end
  end

  describe "round-trip serialization" do
    test "serializes and deserializes preserving all data" do
      original_graph = Graph.new()

      {:ok, original_graph} =
        Graph.add_node(original_graph, "node-1", :agent, %{
          position: %{x: 100, y: 200},
          label: "Agent 1",
          metadata: %{color: "blue", priority: 1}
        })

      {:ok, original_graph} =
        Graph.add_node(original_graph, "node-2", :task, %{
          position: %{x: 300, y: 400},
          label: "Task 1",
          metadata: %{status: "pending"}
        })

      {:ok, original_graph} =
        Graph.add_edge(original_graph, "edge-1", "node-1", "out", "node-2", "in", %{
          label: "connection",
          metadata: %{bandwidth: "high"}
        })

      {:ok, serialized} = Serializer.serialize(original_graph)
      {:ok, deserialized_graph} = Serializer.deserialize(serialized)

      original_nodes = Graph.get_nodes(original_graph) |> Enum.sort_by(& &1.id)
      deserialized_nodes = Graph.get_nodes(deserialized_graph) |> Enum.sort_by(& &1.id)

      assert length(original_nodes) == length(deserialized_nodes)
      assert original_nodes == deserialized_nodes

      original_edges = Graph.get_edges(original_graph) |> Enum.sort_by(& &1.id)
      deserialized_edges = Graph.get_edges(deserialized_graph) |> Enum.sort_by(& &1.id)

      assert length(original_edges) == length(deserialized_edges)
      assert original_edges == deserialized_edges
    end

    test "handles JSON encoding and decoding" do
      graph = Graph.new()

      {:ok, graph} =
        Graph.add_node(graph, "node-1", :agent, %{
          position: %{x: 100, y: 200},
          label: "Test Node",
          metadata: %{key: "value"}
        })

      {:ok, serialized} = Serializer.serialize(graph)
      json_string = Jason.encode!(serialized)
      decoded_data = Jason.decode!(json_string)

      {:ok, restored_graph} = Serializer.deserialize(decoded_data)

      nodes = Graph.get_nodes(restored_graph)
      assert length(nodes) == 1

      node = hd(nodes)
      assert node.id == "node-1"
      assert node.label == "Test Node"
      assert node.metadata == %{"key" => "value"}
    end
  end
end
