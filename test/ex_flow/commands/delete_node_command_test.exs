defmodule ExFlow.Commands.DeleteNodeCommandTest do
  use ExUnit.Case, async: true

  alias ExFlow.Commands.DeleteNodeCommand
  alias ExFlow.Core.Graph

  describe "DeleteNodeCommand" do
    setup do
      # Create a graph with nodes and edges
      graph = Graph.new()

      {:ok, graph} = Graph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 100}})
      {:ok, graph} = Graph.add_node(graph, "node-2", :agent, %{position: %{x: 200, y: 200}})
      {:ok, graph} = Graph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in")

      %{graph: graph}
    end

    test "captures node data and connected edges on creation", %{graph: graph} do
      command = DeleteNodeCommand.new("node-1", graph)

      assert command.node_id == "node-1"
      assert command.node_data != nil
      assert command.node_data.type == :task
      assert command.connected_edges != nil
      assert length(command.connected_edges) == 1
      assert hd(command.connected_edges).id == "edge-1"
    end

    test "execute deletes the node", %{graph: graph} do
      command = DeleteNodeCommand.new("node-1", graph)
      {:ok, new_graph} = DeleteNodeCommand.execute(command, graph)

      # Node should be deleted
      assert {:error, :node_not_found} = Graph.get_node(new_graph, "node-1")

      # Edge should also be deleted (cascade)
      edges = Graph.get_edges(new_graph)
      assert Enum.empty?(edges)
    end

    test "undo restores the node and its connected edges", %{graph: graph} do
      # Create command and execute (delete the node)
      command = DeleteNodeCommand.new("node-1", graph)
      {:ok, graph_after_delete} = DeleteNodeCommand.execute(command, graph)

      # Verify node is deleted
      assert {:error, :node_not_found} = Graph.get_node(graph_after_delete, "node-1")
      assert Enum.empty?(Graph.get_edges(graph_after_delete))

      # Undo the deletion
      {:ok, graph_after_undo} = DeleteNodeCommand.undo(command, graph_after_delete)

      # Node should be restored
      assert {:ok, node} = Graph.get_node(graph_after_undo, "node-1")
      assert node.type == :task
      assert node.position.x == 100
      assert node.position.y == 100

      # Edge should be restored
      edges = Graph.get_edges(graph_after_undo)
      assert length(edges) == 1
      assert hd(edges).id == "edge-1"
      assert hd(edges).source == "node-1"
      assert hd(edges).target == "node-2"
    end

    test "undo handles node with multiple edges", %{graph: graph} do
      # Add another edge
      {:ok, graph} = Graph.add_node(graph, "node-3", :task, %{position: %{x: 300, y: 300}})
      {:ok, graph} = Graph.add_edge(graph, "edge-2", "node-1", "out", "node-3", "in")

      # Create command and execute
      command = DeleteNodeCommand.new("node-1", graph)
      {:ok, graph_after_delete} = DeleteNodeCommand.execute(command, graph)

      # Verify both edges are deleted
      assert Enum.empty?(Graph.get_edges(graph_after_delete))

      # Undo the deletion
      {:ok, graph_after_undo} = DeleteNodeCommand.undo(command, graph_after_delete)

      # Both edges should be restored
      edges = Graph.get_edges(graph_after_undo)
      assert length(edges) == 2
      edge_ids = Enum.map(edges, & &1.id)
      assert "edge-1" in edge_ids
      assert "edge-2" in edge_ids
    end

    test "description returns meaningful text" do
      graph = Graph.new()
      {:ok, graph} = Graph.add_node(graph, "test-node", :task, %{})
      command = DeleteNodeCommand.new("test-node", graph)

      assert DeleteNodeCommand.description(command) == "Delete node 'test-node'"
    end
  end
end
