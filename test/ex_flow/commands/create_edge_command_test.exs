defmodule ExFlow.Commands.CreateEdgeCommandTest do
  use ExUnit.Case, async: true

  alias ExFlow.Commands.CreateEdgeCommand
  alias ExFlow.Core.Graph

  setup do
    graph = Graph.new()
    {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 0, y: 0}})
    {:ok, graph} = Graph.add_node(graph, "node-2", :task, %{position: %{x: 100, y: 100}})
    %{graph: graph}
  end

  describe "new/5 and new/6" do
    test "creates command with required parameters" do
      command = CreateEdgeCommand.new("edge-1", "node-1", "out", "node-2", "in")

      assert command.edge_id == "edge-1"
      assert command.source_id == "node-1"
      assert command.source_handle == "out"
      assert command.target_id == "node-2"
      assert command.target_handle == "in"
      assert command.metadata == %{}
    end

    test "creates command with label and metadata" do
      opts = %{label: "connection", metadata: %{protocol: "http"}}
      command = CreateEdgeCommand.new("edge-1", "node-1", "out", "node-2", "in", opts)

      assert command.label == "connection"
      assert command.metadata == %{protocol: "http"}
    end
  end

  describe "execute/2" do
    test "creates an edge in the graph", %{graph: graph} do
      command = CreateEdgeCommand.new("edge-1", "node-1", "out", "node-2", "in")

      {:ok, graph} = CreateEdgeCommand.execute(command, graph)

      edges = Graph.get_edges(graph)
      assert length(edges) == 1

      edge = hd(edges)
      assert edge.id == "edge-1"
      assert edge.source == "node-1"
      assert edge.target == "node-2"
    end

    test "creates edge with label and metadata", %{graph: graph} do
      opts = %{label: "flow", metadata: %{bandwidth: "high"}}
      command = CreateEdgeCommand.new("edge-1", "node-1", "out", "node-2", "in", opts)

      {:ok, graph} = CreateEdgeCommand.execute(command, graph)

      edges = Graph.get_edges(graph)
      edge = hd(edges)
      assert edge.label == "flow"
      assert edge.metadata == %{bandwidth: "high"}
    end

    test "returns error when source node doesn't exist", %{graph: graph} do
      command = CreateEdgeCommand.new("edge-1", "nonexistent", "out", "node-2", "in")

      result = CreateEdgeCommand.execute(command, graph)
      assert {:error, :source_not_found} = result
    end

    test "returns error when target node doesn't exist", %{graph: graph} do
      command = CreateEdgeCommand.new("edge-1", "node-1", "out", "nonexistent", "in")

      result = CreateEdgeCommand.execute(command, graph)
      assert {:error, :target_not_found} = result
    end
  end

  describe "undo/2" do
    test "removes the created edge", %{graph: graph} do
      command = CreateEdgeCommand.new("edge-1", "node-1", "out", "node-2", "in")

      {:ok, graph} = CreateEdgeCommand.execute(command, graph)
      assert length(Graph.get_edges(graph)) == 1

      {:ok, graph} = CreateEdgeCommand.undo(command, graph)
      assert Graph.get_edges(graph) == []
    end

    test "returns error if edge doesn't exist", %{graph: graph} do
      command = CreateEdgeCommand.new("edge-1", "node-1", "out", "node-2", "in")

      result = CreateEdgeCommand.undo(command, graph)
      assert {:error, :edge_not_found} = result
    end
  end

  describe "description/1" do
    test "returns human-readable description" do
      command = CreateEdgeCommand.new("edge-1", "node-1", "out", "node-2", "in")
      description = CreateEdgeCommand.description(command)

      assert description == "Create edge from 'node-1' to 'node-2'"
    end
  end
end
