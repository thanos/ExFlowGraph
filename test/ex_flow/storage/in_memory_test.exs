defmodule ExFlow.Storage.InMemoryTest do
  use ExUnit.Case, async: false

  alias ExFlow.Core.Graph, as: FlowGraph
  alias ExFlow.Storage.InMemory

  setup do
    # Start a fresh InMemory storage for each test
    {:ok, _pid} = start_supervised(InMemory)
    :ok
  end

  describe "save/2 and load/1" do
    test "saves and loads a graph successfully" do
      # Create a graph with nodes and edges
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 200}})
      {:ok, graph} = FlowGraph.add_node(graph, "node-2", :agent, %{position: %{x: 300, y: 400}})
      {:ok, graph} = FlowGraph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in")

      # Save the graph
      assert :ok = InMemory.save("test-graph", graph)

      # Load the graph
      assert {:ok, loaded_graph} = InMemory.load("test-graph")

      # Verify nodes
      assert {:ok, node1} = FlowGraph.get_node(loaded_graph, "node-1")
      assert node1.type == :task
      assert node1.position.x == 100
      assert node1.position.y == 200

      assert {:ok, node2} = FlowGraph.get_node(loaded_graph, "node-2")
      assert node2.type == :agent
      assert node2.position.x == 300
      assert node2.position.y == 400

      # Verify edges
      edges = FlowGraph.get_edges(loaded_graph)
      assert length(edges) == 1
      edge = hd(edges)
      assert edge.id == "edge-1"
      assert edge.source == "node-1"
      assert edge.target == "node-2"
    end

    test "returns error when loading non-existent graph" do
      assert {:error, :not_found} = InMemory.load("non-existent")
    end

    test "overwrites existing graph on save" do
      graph1 = FlowGraph.new()
      {:ok, graph1} = FlowGraph.add_node(graph1, "node-1", :task, %{position: %{x: 100, y: 100}})

      graph2 = FlowGraph.new()
      {:ok, graph2} = FlowGraph.add_node(graph2, "node-2", :agent, %{position: %{x: 200, y: 200}})

      # Save first graph
      assert :ok = InMemory.save("my-graph", graph1)

      # Save second graph with same ID
      assert :ok = InMemory.save("my-graph", graph2)

      # Load and verify it's the second graph
      assert {:ok, loaded_graph} = InMemory.load("my-graph")
      assert {:error, :node_not_found} = FlowGraph.get_node(loaded_graph, "node-1")
      assert {:ok, _node2} = FlowGraph.get_node(loaded_graph, "node-2")
    end

    test "handles empty graphs" do
      graph = FlowGraph.new()

      assert :ok = InMemory.save("empty-graph", graph)
      assert {:ok, loaded_graph} = InMemory.load("empty-graph")

      assert Enum.empty?(FlowGraph.get_nodes(loaded_graph))
      assert Enum.empty?(FlowGraph.get_edges(loaded_graph))
    end

    test "handles graphs with only nodes" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 100}})
      {:ok, graph} = FlowGraph.add_node(graph, "node-2", :agent, %{position: %{x: 200, y: 200}})

      assert :ok = InMemory.save("nodes-only", graph)
      assert {:ok, loaded_graph} = InMemory.load("nodes-only")

      assert length(FlowGraph.get_nodes(loaded_graph)) == 2
      assert Enum.empty?(FlowGraph.get_edges(loaded_graph))
    end

    test "handles complex graphs with multiple edges" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 100}})
      {:ok, graph} = FlowGraph.add_node(graph, "node-2", :agent, %{position: %{x: 200, y: 200}})
      {:ok, graph} = FlowGraph.add_node(graph, "node-3", :task, %{position: %{x: 300, y: 300}})

      {:ok, graph} = FlowGraph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in")
      {:ok, graph} = FlowGraph.add_edge(graph, "edge-2", "node-2", "out", "node-3", "in")
      {:ok, graph} = FlowGraph.add_edge(graph, "edge-3", "node-1", "out", "node-3", "in")

      assert :ok = InMemory.save("complex-graph", graph)
      assert {:ok, loaded_graph} = InMemory.load("complex-graph")

      assert length(FlowGraph.get_nodes(loaded_graph)) == 3
      assert length(FlowGraph.get_edges(loaded_graph)) == 3
    end
  end

  describe "delete/1" do
    test "deletes an existing graph" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 100}})

      # Save and verify it exists
      assert :ok = InMemory.save("to-delete", graph)
      assert {:ok, _} = InMemory.load("to-delete")

      # Delete the graph
      assert :ok = InMemory.delete("to-delete")

      # Verify it's gone
      assert {:error, :not_found} = InMemory.load("to-delete")
    end

    test "returns ok when deleting non-existent graph (idempotent)" do
      # Delete is idempotent - returns :ok even if graph doesn't exist
      assert :ok = InMemory.delete("non-existent")
    end

    test "deleting one graph doesn't affect others" do
      graph1 = FlowGraph.new()
      {:ok, graph1} = FlowGraph.add_node(graph1, "node-1", :task, %{position: %{x: 100, y: 100}})

      graph2 = FlowGraph.new()
      {:ok, graph2} = FlowGraph.add_node(graph2, "node-2", :agent, %{position: %{x: 200, y: 200}})

      # Save both graphs
      assert :ok = InMemory.save("graph-1", graph1)
      assert :ok = InMemory.save("graph-2", graph2)

      # Delete first graph
      assert :ok = InMemory.delete("graph-1")

      # Verify first is gone but second remains
      assert {:error, :not_found} = InMemory.load("graph-1")
      assert {:ok, _} = InMemory.load("graph-2")
    end
  end

  describe "list/0" do
    test "returns empty list when no graphs exist" do
      assert [] = InMemory.list()
    end

    test "returns list of saved graph IDs" do
      graph = FlowGraph.new()

      assert :ok = InMemory.save("graph-1", graph)
      assert :ok = InMemory.save("graph-2", graph)
      assert :ok = InMemory.save("graph-3", graph)

      graph_ids = InMemory.list()
      assert length(graph_ids) == 3
      assert "graph-1" in graph_ids
      assert "graph-2" in graph_ids
      assert "graph-3" in graph_ids
    end

    test "list updates after delete" do
      graph = FlowGraph.new()

      assert :ok = InMemory.save("graph-1", graph)
      assert :ok = InMemory.save("graph-2", graph)

      assert length(InMemory.list()) == 2

      assert :ok = InMemory.delete("graph-1")

      graph_ids = InMemory.list()
      assert length(graph_ids) == 1
      assert "graph-2" in graph_ids
      refute "graph-1" in graph_ids
    end

    test "list shows updated graph after overwrite" do
      graph = FlowGraph.new()

      assert :ok = InMemory.save("graph-1", graph)
      assert length(InMemory.list()) == 1

      # Overwrite with same ID
      assert :ok = InMemory.save("graph-1", graph)
      assert length(InMemory.list()) == 1
    end
  end

  describe "concurrent access" do
    test "handles concurrent saves" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 100}})

      # Save multiple graphs concurrently
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            InMemory.save("graph-#{i}", graph)
          end)
        end

      results = Task.await_many(tasks)
      assert Enum.all?(results, &(&1 == :ok))

      # Verify all were saved
      assert length(InMemory.list()) == 10
    end

    test "handles concurrent reads" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 100}})

      assert :ok = InMemory.save("shared-graph", graph)

      # Read concurrently
      tasks =
        for _ <- 1..10 do
          Task.async(fn ->
            InMemory.load("shared-graph")
          end)
        end

      results = Task.await_many(tasks)
      assert Enum.all?(results, fn {:ok, _} -> true end)
    end

    test "handles concurrent save and delete" do
      graph = FlowGraph.new()

      # Concurrently save and delete
      save_task = Task.async(fn -> InMemory.save("concurrent-graph", graph) end)
      delete_task = Task.async(fn -> InMemory.delete("concurrent-graph") end)

      Task.await(save_task)
      Task.await(delete_task)

      # Either the graph exists or it doesn't, both are valid outcomes
      case InMemory.load("concurrent-graph") do
        {:ok, _} -> assert true
        {:error, :not_found} -> assert true
      end
    end
  end

  describe "metadata preservation" do
    test "preserves node metadata" do
      graph = FlowGraph.new()

      {:ok, graph} =
        FlowGraph.add_node(graph, "node-1", :task, %{
          position: %{x: 100, y: 200},
          metadata: %{
            label: "My Task",
            description: "A test task",
            priority: :high
          }
        })

      assert :ok = InMemory.save("metadata-graph", graph)
      assert {:ok, loaded_graph} = InMemory.load("metadata-graph")

      assert {:ok, node} = FlowGraph.get_node(loaded_graph, "node-1")
      assert node.metadata.label == "My Task"
      assert node.metadata.description == "A test task"
      assert node.metadata.priority == :high
    end

    test "preserves edge metadata" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 100}})
      {:ok, graph} = FlowGraph.add_node(graph, "node-2", :agent, %{position: %{x: 200, y: 200}})

      {:ok, graph} =
        FlowGraph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in", %{
          label: "connects to",
          weight: 5
        })

      assert :ok = InMemory.save("edge-metadata-graph", graph)
      assert {:ok, loaded_graph} = InMemory.load("edge-metadata-graph")

      edges = FlowGraph.get_edges(loaded_graph)
      edge = hd(edges)
      assert edge.metadata.label == "connects to"
      assert edge.metadata.weight == 5
    end
  end
end
