defmodule ExFlow.Commands.DeleteEdgeCommandTest do
  use ExUnit.Case, async: true

  alias ExFlow.Commands.DeleteEdgeCommand
  alias ExFlow.Core.Graph

  setup do
    graph = Graph.new()
    {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 0, y: 0}})
    {:ok, graph} = Graph.add_node(graph, "node-2", :task, %{position: %{x: 100, y: 100}})
    {:ok, graph} = Graph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in")
    %{graph: graph}
  end

  describe "new/2" do
    test "creates command with edge id and captures edge data", %{graph: graph} do
      command = DeleteEdgeCommand.new("edge-1", graph)
      assert command.edge_id == "edge-1"
      assert command.edge_data != nil
      assert command.edge_data.id == "edge-1"
    end
  end

  describe "execute/2" do
    test "deletes an existing edge", %{graph: graph} do
      command = DeleteEdgeCommand.new("edge-1", graph)

      assert length(Graph.get_edges(graph)) == 1

      {:ok, graph} = DeleteEdgeCommand.execute(command, graph)

      assert Graph.get_edges(graph) == []
    end

    test "stores edge data for undo", %{graph: graph} do
      command = DeleteEdgeCommand.new("edge-1", graph)

      {:ok, _graph} = DeleteEdgeCommand.execute(command, graph)

      # The command should have edge_data stored from creation
      assert command.edge_data != nil
    end

    test "returns error when edge doesn't exist", %{graph: graph} do
      command = DeleteEdgeCommand.new("nonexistent", graph)

      result = DeleteEdgeCommand.execute(command, graph)
      assert {:error, :edge_not_found} = result
    end
  end

  describe "undo/2" do
    test "recreates the deleted edge", %{graph: graph} do
      edges_before = Graph.get_edges(graph)
      edge_before = hd(edges_before)

      command = DeleteEdgeCommand.new("edge-1", graph)
      {:ok, graph} = DeleteEdgeCommand.execute(command, graph)

      assert Graph.get_edges(graph) == []

      {:ok, graph} = DeleteEdgeCommand.undo(command, graph)

      edges_after = Graph.get_edges(graph)
      assert length(edges_after) == 1

      edge_after = hd(edges_after)
      assert edge_after.id == edge_before.id
      assert edge_after.source == edge_before.source
      assert edge_after.target == edge_before.target
    end

    test "returns error if edge_data is not stored" do
      graph = Graph.new()
      # When edge doesn't exist, edge_data will be nil
      command = DeleteEdgeCommand.new("edge-1", graph)

      result = DeleteEdgeCommand.undo(command, graph)
      # Should fail because edge_data is nil
      assert match?({:error, _}, result)
    end
  end

  describe "description/1" do
    test "returns human-readable description", %{graph: graph} do
      command = DeleteEdgeCommand.new("edge-1", graph)
      description = DeleteEdgeCommand.description(command)

      assert description == "Delete edge 'edge-1'"
    end
  end
end
