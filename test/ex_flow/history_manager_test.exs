defmodule ExFlow.HistoryManagerTest do
  use ExUnit.Case, async: true

  alias ExFlow.Commands.{CreateNodeCommand, DeleteNodeCommand}
  alias ExFlow.Core.Graph
  alias ExFlow.HistoryManager

  describe "new/0 and new/1" do
    test "creates a new history manager with default max size" do
      history = HistoryManager.new()
      assert history.max_size == 50
      assert history.past == []
      assert history.future == []
    end

    test "creates a new history manager with custom max size" do
      history = HistoryManager.new(100)
      assert history.max_size == 100
      assert history.past == []
      assert history.future == []
    end
  end

  describe "execute/3" do
    test "executes a command and adds it to history" do
      graph = Graph.new()
      history = HistoryManager.new()
      command = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})

      {:ok, history, graph} = HistoryManager.execute(history, command, graph)

      assert length(history.past) == 1
      assert history.future == []
      {:ok, node} = Graph.get_node(graph, "node-1")
      assert node.id == "node-1"
    end

    test "clears future stack when executing new command" do
      graph = Graph.new()
      history = HistoryManager.new()

      # Execute and undo to populate future stack
      command1 = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})
      {:ok, history, graph} = HistoryManager.execute(history, command1, graph)
      {:ok, history, graph} = HistoryManager.undo(history, graph)

      assert length(history.future) == 1

      # Execute new command should clear future
      command2 = CreateNodeCommand.new("node-2", :task, %{position: %{x: 100, y: 100}})
      {:ok, history, _graph} = HistoryManager.execute(history, command2, graph)

      assert length(history.past) == 1
      assert history.future == []
    end

    test "respects max_size limit" do
      graph = Graph.new()
      history = HistoryManager.new(2)

      # Execute 3 commands
      command1 = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})
      command2 = CreateNodeCommand.new("node-2", :agent, %{position: %{x: 0, y: 0}})
      command3 = CreateNodeCommand.new("node-3", :agent, %{position: %{x: 0, y: 0}})

      {:ok, history, graph} = HistoryManager.execute(history, command1, graph)
      {:ok, history, graph} = HistoryManager.execute(history, command2, graph)
      {:ok, history, _graph} = HistoryManager.execute(history, command3, graph)

      # Should only keep last 2
      assert length(history.past) == 2
    end

    test "returns error when command fails" do
      graph = Graph.new()
      history = HistoryManager.new()

      # Try to delete non-existent node
      command = DeleteNodeCommand.new("nonexistent", graph)
      result = HistoryManager.execute(history, command, graph)

      assert {:error, _} = result
    end
  end

  describe "undo/2" do
    test "undoes the last command" do
      graph = Graph.new()
      history = HistoryManager.new()

      command = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})
      {:ok, history, graph} = HistoryManager.execute(history, command, graph)

      assert {:ok, _node} = Graph.get_node(graph, "node-1")

      {:ok, history, graph} = HistoryManager.undo(history, graph)

      assert {:error, :node_not_found} = Graph.get_node(graph, "node-1")
      assert history.past == []
      assert length(history.future) == 1
    end

    test "returns error when nothing to undo" do
      graph = Graph.new()
      history = HistoryManager.new()

      result = HistoryManager.undo(history, graph)
      assert result == {:error, :nothing_to_undo}
    end

    test "moves command from past to future" do
      graph = Graph.new()
      history = HistoryManager.new()

      command1 = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})
      command2 = CreateNodeCommand.new("node-2", :agent, %{position: %{x: 0, y: 0}})

      {:ok, history, graph} = HistoryManager.execute(history, command1, graph)
      {:ok, history, graph} = HistoryManager.execute(history, command2, graph)

      assert length(history.past) == 2
      assert history.future == []

      {:ok, history, _graph} = HistoryManager.undo(history, graph)

      assert length(history.past) == 1
      assert length(history.future) == 1
    end
  end

  describe "redo/2" do
    test "redoes the last undone command" do
      graph = Graph.new()
      history = HistoryManager.new()

      command = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})
      {:ok, history, graph} = HistoryManager.execute(history, command, graph)
      {:ok, history, graph} = HistoryManager.undo(history, graph)

      assert {:error, :node_not_found} = Graph.get_node(graph, "node-1")

      {:ok, history, graph} = HistoryManager.redo(history, graph)

      assert {:ok, _node} = Graph.get_node(graph, "node-1")
      assert length(history.past) == 1
      assert history.future == []
    end

    test "returns error when nothing to redo" do
      graph = Graph.new()
      history = HistoryManager.new()

      result = HistoryManager.redo(history, graph)
      assert result == {:error, :nothing_to_redo}
    end

    test "moves command from future to past" do
      graph = Graph.new()
      history = HistoryManager.new()

      command = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})
      {:ok, history, graph} = HistoryManager.execute(history, command, graph)
      {:ok, history, graph} = HistoryManager.undo(history, graph)

      assert history.past == []
      assert length(history.future) == 1

      {:ok, history, _graph} = HistoryManager.redo(history, graph)

      assert length(history.past) == 1
      assert history.future == []
    end
  end

  describe "can_undo?/1 and can_redo?/1" do
    test "can_undo? returns true when there is history" do
      graph = Graph.new()
      history = HistoryManager.new()
      command = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})

      {:ok, history, _graph} = HistoryManager.execute(history, command, graph)

      assert HistoryManager.can_undo?(history) == true
    end

    test "can_undo? returns false when there is no history" do
      history = HistoryManager.new()
      assert HistoryManager.can_undo?(history) == false
    end

    test "can_redo? returns true when there is future history" do
      graph = Graph.new()
      history = HistoryManager.new()
      command = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})

      {:ok, history, graph} = HistoryManager.execute(history, command, graph)
      {:ok, history, _graph} = HistoryManager.undo(history, graph)

      assert HistoryManager.can_redo?(history) == true
    end

    test "can_redo? returns false when there is no future history" do
      history = HistoryManager.new()
      assert HistoryManager.can_redo?(history) == false
    end
  end

  describe "next_undo_description/1 and next_redo_description/1" do
    test "next_undo_description returns description of next command to undo" do
      graph = Graph.new()
      history = HistoryManager.new()
      command = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})

      {:ok, history, _graph} = HistoryManager.execute(history, command, graph)

      description = HistoryManager.next_undo_description(history)
      assert description == "Create agent node 'node-1'"
    end

    test "next_undo_description returns nil when nothing to undo" do
      history = HistoryManager.new()
      assert HistoryManager.next_undo_description(history) == nil
    end

    test "next_redo_description returns description of next command to redo" do
      graph = Graph.new()
      history = HistoryManager.new()
      command = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})

      {:ok, history, graph} = HistoryManager.execute(history, command, graph)
      {:ok, history, _graph} = HistoryManager.undo(history, graph)

      description = HistoryManager.next_redo_description(history)
      assert description == "Create agent node 'node-1'"
    end

    test "next_redo_description returns nil when nothing to redo" do
      history = HistoryManager.new()
      assert HistoryManager.next_redo_description(history) == nil
    end
  end

  describe "clear/1" do
    test "clears all history" do
      graph = Graph.new()
      history = HistoryManager.new()

      command1 = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})
      command2 = CreateNodeCommand.new("node-2", :agent, %{position: %{x: 0, y: 0}})

      {:ok, history, graph} = HistoryManager.execute(history, command1, graph)
      {:ok, history, graph} = HistoryManager.execute(history, command2, graph)
      {:ok, history, _graph} = HistoryManager.undo(history, graph)

      assert length(history.past) == 1
      assert length(history.future) == 1

      history = HistoryManager.clear(history)

      assert history.past == []
      assert history.future == []
    end
  end

  describe "past_count/1 and future_count/1" do
    test "returns correct counts" do
      graph = Graph.new()
      history = HistoryManager.new()

      assert HistoryManager.past_count(history) == 0
      assert HistoryManager.future_count(history) == 0

      command1 = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})
      command2 = CreateNodeCommand.new("node-2", :agent, %{position: %{x: 0, y: 0}})

      {:ok, history, graph} = HistoryManager.execute(history, command1, graph)
      {:ok, history, graph} = HistoryManager.execute(history, command2, graph)

      assert HistoryManager.past_count(history) == 2
      assert HistoryManager.future_count(history) == 0

      {:ok, history, _graph} = HistoryManager.undo(history, graph)

      assert HistoryManager.past_count(history) == 1
      assert HistoryManager.future_count(history) == 1
    end
  end

  describe "complex scenarios" do
    test "multiple undo/redo cycles" do
      graph = Graph.new()
      history = HistoryManager.new()

      command = CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}})

      # Execute
      {:ok, history, graph} = HistoryManager.execute(history, command, graph)
      assert {:ok, _} = Graph.get_node(graph, "node-1")

      # Undo
      {:ok, history, graph} = HistoryManager.undo(history, graph)
      assert {:error, :node_not_found} = Graph.get_node(graph, "node-1")

      # Redo
      {:ok, history, graph} = HistoryManager.redo(history, graph)
      assert {:ok, _} = Graph.get_node(graph, "node-1")

      # Undo again
      {:ok, _history, graph} = HistoryManager.undo(history, graph)
      assert {:error, :node_not_found} = Graph.get_node(graph, "node-1")
    end

    test "undo multiple commands and redo selectively" do
      graph = Graph.new()
      history = HistoryManager.new()

      {:ok, history, graph} =
        HistoryManager.execute(
          history,
          CreateNodeCommand.new("node-1", :agent, %{position: %{x: 0, y: 0}}),
          graph
        )

      {:ok, history, graph} =
        HistoryManager.execute(
          history,
          CreateNodeCommand.new("node-2", :agent, %{position: %{x: 0, y: 0}}),
          graph
        )

      {:ok, history, graph} =
        HistoryManager.execute(
          history,
          CreateNodeCommand.new("node-3", :agent, %{position: %{x: 0, y: 0}}),
          graph
        )

      # Undo all three
      {:ok, history, graph} = HistoryManager.undo(history, graph)
      {:ok, history, graph} = HistoryManager.undo(history, graph)
      {:ok, history, graph} = HistoryManager.undo(history, graph)

      assert Graph.get_nodes(graph) == []

      # Redo first two
      {:ok, history, graph} = HistoryManager.redo(history, graph)
      {:ok, _history, graph} = HistoryManager.redo(history, graph)

      nodes = Graph.get_nodes(graph)
      assert length(nodes) == 2
    end
  end
end
