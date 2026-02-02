defmodule ExFlow.Commands.MoveNodeCommandTest do
  use ExUnit.Case, async: true

  alias ExFlow.Commands.MoveNodeCommand
  alias ExFlow.Core.Graph

  setup do
    graph = Graph.new()
    {:ok, graph} = Graph.add_node(graph, "node-1", :agent, %{position: %{x: 0, y: 0}})
    %{graph: graph}
  end

  describe "new/3" do
    test "creates command with node id, old position, and new position" do
      command = MoveNodeCommand.new("node-1", %{x: 0, y: 0}, %{x: 100, y: 200})

      assert command.node_id == "node-1"
      assert command.old_position == %{x: 0, y: 0}
      assert command.new_position == %{x: 100, y: 200}
    end
  end

  describe "execute/2" do
    test "updates node position", %{graph: graph} do
      command = MoveNodeCommand.new("node-1", %{x: 0, y: 0}, %{x: 150, y: 250})

      {:ok, graph} = MoveNodeCommand.execute(command, graph)

      {:ok, node} = Graph.get_node(graph, "node-1")
      assert node.position == %{x: 150, y: 250}
    end

    test "old position is stored in command", %{graph: graph} do
      command = MoveNodeCommand.new("node-1", %{x: 0, y: 0}, %{x: 150, y: 250})

      {:ok, _graph} = MoveNodeCommand.execute(command, graph)

      # The command already has old_position stored from creation
      assert command.old_position == %{x: 0, y: 0}
    end

    test "returns error when node doesn't exist", %{graph: graph} do
      command = MoveNodeCommand.new("nonexistent", %{x: 0, y: 0}, %{x: 100, y: 100})

      result = MoveNodeCommand.execute(command, graph)
      assert {:error, :node_not_found} = result
    end
  end

  describe "undo/2" do
    test "restores original position", %{graph: graph} do
      command = MoveNodeCommand.new("node-1", %{x: 0, y: 0}, %{x: 150, y: 250})

      {:ok, graph} = MoveNodeCommand.execute(command, graph)

      {:ok, node} = Graph.get_node(graph, "node-1")
      assert node.position == %{x: 150, y: 250}

      {:ok, graph} = MoveNodeCommand.undo(command, graph)

      {:ok, node} = Graph.get_node(graph, "node-1")
      assert node.position == %{x: 0, y: 0}
    end

    test "returns error when node doesn't exist", %{graph: graph} do
      command = MoveNodeCommand.new("nonexistent", %{x: 0, y: 0}, %{x: 100, y: 100})

      result = MoveNodeCommand.undo(command, graph)
      assert {:error, :node_not_found} = result
    end
  end

  describe "description/1" do
    test "returns human-readable description" do
      command = MoveNodeCommand.new("node-1", %{x: 0, y: 0}, %{x: 150, y: 250})
      description = MoveNodeCommand.description(command)

      assert description == "Move node 'node-1'"
    end
  end
end
