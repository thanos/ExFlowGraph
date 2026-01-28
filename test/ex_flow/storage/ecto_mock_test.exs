defmodule ExFlow.Storage.EctoMockTest do
  use ExUnit.Case, async: true

  import Mox

  alias ExFlow.Core.Graph, as: FlowGraph
  alias ExFlow.GraphRecord
  alias ExFlow.Storage.Ecto, as: EctoStorage

  # Define a mock for the Ecto Repo
  setup :verify_on_exit!

  setup do
    # Configure the application to use our mock repo
    Application.put_env(:ex_flow, :repo, ExFlow.RepoMock)
    
    on_exit(fn ->
      Application.delete_env(:ex_flow, :repo)
    end)
    
    :ok
  end

  describe "load/1 with mocked repo" do
    test "loads a graph successfully" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 200}})
      {:ok, serialized} = ExFlow.Serializer.serialize(graph)

      record = %GraphRecord{
        id: 1,
        name: "test-graph",
        data: serialized,
        version: 1
      }

      # Mock the repo.get_by call
      expect(ExFlow.RepoMock, :get_by, fn GraphRecord, [name: "test-graph"] ->
        record
      end)

      # Call load
      assert {:ok, loaded_graph} = EctoStorage.load("test-graph")
      assert {:ok, _node} = FlowGraph.get_node(loaded_graph, "node-1")
    end

    test "returns error when graph not found" do
      # Mock the repo.get_by to return nil
      expect(ExFlow.RepoMock, :get_by, fn GraphRecord, [name: "non-existent"] ->
        nil
      end)

      assert {:error, :not_found} = EctoStorage.load("non-existent")
    end

    test "handles missing nodes/edges gracefully" do
      # The serializer is forgiving and will create an empty graph from incomplete data
      record = %GraphRecord{
        id: 1,
        name: "incomplete-graph",
        data: %{},
        version: 1
      }

      expect(ExFlow.RepoMock, :get_by, fn GraphRecord, [name: "incomplete-graph"] ->
        record
      end)

      # Should succeed and return an empty graph
      assert {:ok, graph} = EctoStorage.load("incomplete-graph")
      assert Enum.empty?(FlowGraph.get_nodes(graph))
      assert Enum.empty?(FlowGraph.get_edges(graph))
    end
  end

  describe "save/2 with mocked repo" do
    test "inserts new graph successfully" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 200}})

      # Mock repo.get_by to return nil (graph doesn't exist)
      expect(ExFlow.RepoMock, :get_by, fn GraphRecord, [name: "new-graph"] ->
        nil
      end)

      # Mock repo.insert to succeed
      expect(ExFlow.RepoMock, :insert, fn changeset ->
        {:ok, %GraphRecord{
          id: 1,
          name: "new-graph",
          data: changeset.changes.data,
          version: 1
        }}
      end)

      assert :ok = EctoStorage.save("new-graph", graph)
    end

    test "updates existing graph successfully" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 200}})
      {:ok, serialized} = ExFlow.Serializer.serialize(graph)

      existing_record = %GraphRecord{
        id: 1,
        name: "existing-graph",
        data: serialized,
        version: 1
      }

      # Mock repo.get_by to return existing record
      expect(ExFlow.RepoMock, :get_by, fn GraphRecord, [name: "existing-graph"] ->
        existing_record
      end)

      # Mock repo.update to succeed
      expect(ExFlow.RepoMock, :update, fn changeset ->
        # Extract data from changeset - it should be in changes
        new_data = Map.get(changeset.changes, :data, serialized)
        {:ok, %GraphRecord{
          id: 1,
          name: "existing-graph",
          data: new_data,
          version: 2
        }}
      end)

      assert :ok = EctoStorage.save("existing-graph", graph)
    end

    test "returns error when insert fails" do
      graph = FlowGraph.new()

      expect(ExFlow.RepoMock, :get_by, fn GraphRecord, [name: "error-graph"] ->
        nil
      end)

      changeset_error = %Ecto.Changeset{
        valid?: false,
        errors: [name: {"has already been taken", []}]
      }

      expect(ExFlow.RepoMock, :insert, fn _changeset ->
        {:error, changeset_error}
      end)

      assert {:error, _} = EctoStorage.save("error-graph", graph)
    end

    test "returns error when update fails" do
      graph = FlowGraph.new()
      {:ok, serialized} = ExFlow.Serializer.serialize(graph)

      existing_record = %GraphRecord{
        id: 1,
        name: "update-error",
        data: serialized,
        version: 1
      }

      expect(ExFlow.RepoMock, :get_by, fn GraphRecord, [name: "update-error"] ->
        existing_record
      end)

      changeset_error = %Ecto.Changeset{
        valid?: false,
        errors: [version: {"stale", []}]
      }

      expect(ExFlow.RepoMock, :update, fn _changeset ->
        {:error, changeset_error}
      end)

      assert {:error, _} = EctoStorage.save("update-error", graph)
    end
  end

  describe "delete/1 with mocked repo" do
    test "deletes existing graph successfully" do
      record = %GraphRecord{
        id: 1,
        name: "delete-me",
        data: %{},
        version: 1
      }

      # Mock repo.get_by to return the record
      expect(ExFlow.RepoMock, :get_by, fn GraphRecord, [name: "delete-me"] ->
        record
      end)

      # Mock repo.delete to succeed
      expect(ExFlow.RepoMock, :delete, fn ^record ->
        {:ok, record}
      end)

      assert :ok = EctoStorage.delete("delete-me")
    end

    test "returns error when graph not found" do
      expect(ExFlow.RepoMock, :get_by, fn GraphRecord, [name: "non-existent"] ->
        nil
      end)

      assert {:error, :not_found} = EctoStorage.delete("non-existent")
    end

    test "returns error when delete fails" do
      record = %GraphRecord{
        id: 1,
        name: "delete-error",
        data: %{},
        version: 1
      }

      expect(ExFlow.RepoMock, :get_by, fn GraphRecord, [name: "delete-error"] ->
        record
      end)

      changeset_error = %Ecto.Changeset{
        valid?: false,
        errors: [constraint: {"foreign key violation", []}]
      }

      expect(ExFlow.RepoMock, :delete, fn ^record ->
        {:error, changeset_error}
      end)

      assert {:error, _} = EctoStorage.delete("delete-error")
    end
  end

  describe "list/0 with mocked repo" do
    test "returns list of graph names" do
      # Mock repo.all to return list of names
      expect(ExFlow.RepoMock, :all, fn _query ->
        ["graph-1", "graph-2", "graph-3"]
      end)

      assert ["graph-1", "graph-2", "graph-3"] = EctoStorage.list()
    end

    test "returns empty list when no graphs exist" do
      expect(ExFlow.RepoMock, :all, fn _query ->
        []
      end)

      assert [] = EctoStorage.list()
    end
  end

  describe "optimistic locking with mocked repo" do
    test "increments version on update" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 200}})
      {:ok, serialized} = ExFlow.Serializer.serialize(graph)

      existing_record = %GraphRecord{
        id: 1,
        name: "versioned-graph",
        data: serialized,
        version: 5
      }

      expect(ExFlow.RepoMock, :get_by, fn GraphRecord, [name: "versioned-graph"] ->
        existing_record
      end)

      # Verify version is incremented
      expect(ExFlow.RepoMock, :update, fn changeset ->
        assert changeset.changes.version == 6
        new_data = Map.get(changeset.changes, :data, serialized)
        {:ok, %GraphRecord{
          id: 1,
          name: "versioned-graph",
          data: new_data,
          version: 6
        }}
      end)

      assert :ok = EctoStorage.save("versioned-graph", graph)
    end
  end

  describe "serialization edge cases with mocked repo" do
    test "handles complex graphs with multiple nodes and edges" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 100}})
      {:ok, graph} = FlowGraph.add_node(graph, "node-2", :agent, %{position: %{x: 200, y: 200}})
      {:ok, graph} = FlowGraph.add_node(graph, "node-3", :task, %{position: %{x: 300, y: 300}})
      {:ok, graph} = FlowGraph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in")
      {:ok, graph} = FlowGraph.add_edge(graph, "edge-2", "node-2", "out", "node-3", "in")

      expect(ExFlow.RepoMock, :get_by, fn GraphRecord, [name: "complex-graph"] ->
        nil
      end)

      expect(ExFlow.RepoMock, :insert, fn changeset ->
        # Verify the data can be serialized
        assert is_map(changeset.changes.data)
        assert Map.has_key?(changeset.changes.data, :nodes)
        assert Map.has_key?(changeset.changes.data, :edges)
        assert length(changeset.changes.data.nodes) == 3
        assert length(changeset.changes.data.edges) == 2

        {:ok, %GraphRecord{
          id: 1,
          name: "complex-graph",
          data: changeset.changes.data,
          version: 1
        }}
      end)

      assert :ok = EctoStorage.save("complex-graph", graph)
    end

    test "handles empty graphs" do
      graph = FlowGraph.new()

      expect(ExFlow.RepoMock, :get_by, fn GraphRecord, [name: "empty-graph"] ->
        nil
      end)

      expect(ExFlow.RepoMock, :insert, fn changeset ->
        assert changeset.changes.data.nodes == []
        assert changeset.changes.data.edges == []

        {:ok, %GraphRecord{
          id: 1,
          name: "empty-graph",
          data: changeset.changes.data,
          version: 1
        }}
      end)

      assert :ok = EctoStorage.save("empty-graph", graph)
    end
  end
end
