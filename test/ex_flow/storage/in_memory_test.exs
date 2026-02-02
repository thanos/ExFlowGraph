defmodule ExFlow.Storage.InMemoryTest do
  use ExUnit.Case, async: false

  alias ExFlow.Core.Graph
  alias ExFlow.Storage.InMemory

  setup do
    # Clean up any existing data before each test
    Agent.update(InMemory, fn _state -> %{} end)
    :ok
  end

  describe "save/2" do
    test "saves a graph with given id" do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 100, y: 200}})

      result = InMemory.save("test-graph", graph)
      assert result == :ok
    end

    test "overwrites existing graph with same id" do
      graph1 = Graph.new()
      {:ok, graph1} = Graph.add_node(graph1, "node-1", :agent, %{position: %{x: 0, y: 0}})

      InMemory.save("test-graph", graph1)

      graph2 = Graph.new()
      {:ok, graph2} = Graph.add_node(graph2, "node-2", :task, %{position: %{x: 100, y: 100}})

      InMemory.save("test-graph", graph2)

      {:ok, loaded_graph} = InMemory.load("test-graph")
      nodes = Graph.get_nodes(loaded_graph)

      assert length(nodes) == 1
      assert hd(nodes).id == "node-2"
    end
  end

  describe "load/1" do
    test "loads a previously saved graph" do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 100, y: 200}})

      InMemory.save("test-graph", graph)

      {:ok, loaded_graph} = InMemory.load("test-graph")

      nodes = Graph.get_nodes(loaded_graph)
      assert length(nodes) == 1

      node = hd(nodes)
      assert node.id == "node-1"
      assert node.type == :agent
      assert node.position == %{x: 100, y: 200}
    end

    test "returns error for non-existent graph" do
      result = InMemory.load("nonexistent")
      assert result == {:error, :not_found}
    end

    test "preserves all graph data" do
      graph = Graph.new()

      {:ok, graph} =
        Graph.add_node(graph, "node-1", :agent, %{
          position: %{x: 0, y: 0},
          label: "Agent 1",
          metadata: %{color: "blue"}
        })

      {:ok, graph} = Graph.add_node(graph, "node-2", :task, %{position: %{x: 100, y: 100}})

      {:ok, graph} =
        Graph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in", %{label: "connection"})

      InMemory.save("test-graph", graph)
      {:ok, loaded_graph} = InMemory.load("test-graph")

      nodes = Graph.get_nodes(loaded_graph)
      edges = Graph.get_edges(loaded_graph)

      assert length(nodes) == 2
      assert length(edges) == 1

      node1 = Enum.find(nodes, &(&1.id == "node-1"))
      assert node1.label == "Agent 1"
      assert node1.metadata == %{color: "blue"}

      edge = hd(edges)
      assert edge.label == "connection"
    end
  end

  describe "delete/1" do
    test "deletes an existing graph" do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 0, y: 0}})

      InMemory.save("test-graph", graph)
      assert {:ok, _} = InMemory.load("test-graph")

      result = InMemory.delete("test-graph")
      assert result == :ok

      assert InMemory.load("test-graph") == {:error, :not_found}
    end

    test "returns error when deleting non-existent graph" do
      result = InMemory.delete("nonexistent")
      assert result == {:error, :not_found}
    end
  end

  describe "list/0" do
    test "returns empty list when no graphs saved" do
      result = InMemory.list()
      assert result == []
    end

    test "returns list of all saved graph ids" do
      graph1 = Graph.new()
      graph2 = Graph.new()
      graph3 = Graph.new()

      InMemory.save("graph-1", graph1)
      InMemory.save("graph-2", graph2)
      InMemory.save("graph-3", graph3)

      result = InMemory.list()
      assert length(result) == 3
      assert "graph-1" in result
      assert "graph-2" in result
      assert "graph-3" in result
    end

    test "updates list when graphs are deleted" do
      graph = Graph.new()

      InMemory.save("graph-1", graph)
      InMemory.save("graph-2", graph)

      assert length(InMemory.list()) == 2

      InMemory.delete("graph-1")

      result = InMemory.list()
      assert length(result) == 1
      assert result == ["graph-2"]
    end
  end

  describe "concurrent access" do
    test "handles multiple save operations" do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            graph = Graph.new()

            {:ok, graph} =
              Graph.add_node(graph, "node-#{i}", :agent, %{position: %{x: i * 10, y: i * 10}})

            InMemory.save("graph-#{i}", graph)
          end)
        end

      Enum.each(tasks, &Task.await/1)

      result = InMemory.list()
      assert length(result) == 10
    end
  end
end
