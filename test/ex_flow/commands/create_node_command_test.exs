defmodule ExFlow.Commands.CreateNodeCommandTest do
  use ExUnit.Case, async: true

  alias ExFlow.Commands.CreateNodeCommand
  alias ExFlow.Core.Graph

  describe "new/3" do
    test "creates command with required parameters" do
      command = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 100, y: 200}})

      assert command.node_id == "node-1"
      assert command.node_type == :agent
      assert command.metadata == %{position: %{x: 100, y: 200}}
    end

    test "creates command with default empty metadata" do
      command = CreateNodeCommand.new("node-1", :task)

      assert command.node_id == "node-1"
      assert command.node_type == :task
      assert command.metadata == %{}
    end
  end

  describe "execute/2" do
    test "creates a node in the graph" do
      graph = Graph.new()
      command = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 100, y: 200}})

      {:ok, graph} = CreateNodeCommand.execute(command, graph)

      {:ok, node} = Graph.get_node(graph, "node-1")
      assert node.id == "node-1"
      assert node.type == :agent
      assert node.position == %{x: 100, y: 200}
    end

    test "creates node with metadata" do
      graph = Graph.new()

      command =
        CreateNodeCommand.new("node-1", :agent, %{
          position: %{x: 0, y: 0},
          label: "Test Node",
          metadata: %{color: "blue"}
        })

      {:ok, graph} = CreateNodeCommand.execute(command, graph)

      {:ok, node} = Graph.get_node(graph, "node-1")
      assert node.label == "Test Node"
      assert node.metadata == %{color: "blue"}
    end
  end

  describe "undo/2" do
    test "removes the created node" do
      graph = Graph.new()
      command = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})

      {:ok, graph} = CreateNodeCommand.execute(command, graph)
      assert {:ok, _} = Graph.get_node(graph, "node-1")

      {:ok, graph} = CreateNodeCommand.undo(command, graph)
      assert {:error, :node_not_found} = Graph.get_node(graph, "node-1")
    end

    test "returns error if node doesn't exist" do
      graph = Graph.new()
      command = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})

      result = CreateNodeCommand.undo(command, graph)
      assert {:error, :node_not_found} = result
    end
  end

  describe "description/1" do
    test "returns human-readable description" do
      command = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})
      description = CreateNodeCommand.description(command)

      assert description == "Create agent node 'node-1'"
    end

    test "includes node type in description" do
      command = CreateNodeCommand.new("task-42", :task, %{position: %{x: 0, y: 0}})
      description = CreateNodeCommand.description(command)

      assert description == "Create task node 'task-42'"
    end
  end
end
