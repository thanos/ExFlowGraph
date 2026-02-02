defmodule ExFlow.Storage.EctoTest do
  use ExFlowGraph.DataCase, async: true

  alias ExFlow.Storage.Ecto, as: EctoStorage
  alias ExFlow.Core.Graph, as: FlowGraph
  alias ExFlow.GraphRecord
  alias ExFlowGraph.Repo

  describe "save/2 and load/1" do
    test "saves and loads a graph successfully" do
      # Create a graph with nodes and edges
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 200}})
      {:ok, graph} = FlowGraph.add_node(graph, "node-2", :agent, %{position: %{x: 300, y: 400}})
      {:ok, graph} = FlowGraph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in")

      # Save the graph
      assert :ok = EctoStorage.save("test-graph", graph)

      # Load the graph
      assert {:ok, loaded_graph} = EctoStorage.load("test-graph")

      # Verify nodes
      nodes = FlowGraph.get_nodes(loaded_graph)
      assert length(nodes) == 2
      assert Enum.any?(nodes, fn n -> n.id == "node-1" end)
      assert Enum.any?(nodes, fn n -> n.id == "node-2" end)

      # Verify edges
      edges = FlowGraph.get_edges(loaded_graph)
      assert length(edges) == 1
      assert hd(edges).id == "edge-1"
    end

    test "returns error when loading non-existent graph" do
      assert {:error, :not_found} = EctoStorage.load("non-existent")
    end

    test "updates existing graph on save" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 200}})

      # Save initial version
      assert :ok = EctoStorage.save("update-test", graph)

      # Verify version is 1
      record = Repo.get_by!(GraphRecord, name: "update-test")
      assert record.version == 1

      # Update graph
      {:ok, graph} = FlowGraph.add_node(graph, "node-2", :agent, %{position: %{x: 300, y: 400}})

      # Save updated version
      assert :ok = EctoStorage.save("update-test", graph)

      # Verify version is incremented
      record = Repo.get_by!(GraphRecord, name: "update-test")
      assert record.version == 2

      # Verify updated data
      {:ok, loaded_graph} = EctoStorage.load("update-test")
      nodes = FlowGraph.get_nodes(loaded_graph)
      assert length(nodes) == 2
    end

    test "handles empty graph" do
      graph = FlowGraph.new()

      assert :ok = EctoStorage.save("empty-graph", graph)
      assert {:ok, loaded_graph} = EctoStorage.load("empty-graph")

      assert FlowGraph.get_nodes(loaded_graph) == []
      assert FlowGraph.get_edges(loaded_graph) == []
    end
  end

  describe "delete/1" do
    test "deletes an existing graph" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 200}})

      assert :ok = EctoStorage.save("delete-test", graph)
      assert {:ok, _} = EctoStorage.load("delete-test")

      assert :ok = EctoStorage.delete("delete-test")
      assert {:error, :not_found} = EctoStorage.load("delete-test")
    end

    test "returns error when deleting non-existent graph" do
      assert {:error, :not_found} = EctoStorage.delete("non-existent")
    end
  end

  describe "list/0" do
    test "lists all graph names" do
      graph1 = FlowGraph.new()
      graph2 = FlowGraph.new()

      assert :ok = EctoStorage.save("graph-1", graph1)
      assert :ok = EctoStorage.save("graph-2", graph2)

      names = EctoStorage.list()
      assert "graph-1" in names
      assert "graph-2" in names
    end

    test "returns empty list when no graphs exist" do
      assert EctoStorage.list() == []
    end
  end

  describe "concurrent updates" do
    test "handles multiple saves correctly" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 200}})

      # Save multiple times
      assert :ok = EctoStorage.save("concurrent-test", graph)
      assert :ok = EctoStorage.save("concurrent-test", graph)
      assert :ok = EctoStorage.save("concurrent-test", graph)

      # Verify version increments
      record = Repo.get_by!(GraphRecord, name: "concurrent-test")
      assert record.version == 3
    end
  end

  describe "data validation" do
    test "validates graph data structure" do
      # Create invalid record directly
      changeset =
        GraphRecord.changeset(%GraphRecord{}, %{
          name: "invalid",
          data: %{"invalid" => "structure"}
        })

      refute changeset.valid?
      assert "must contain nodes" in errors_on(changeset).data
    end
  end
end
