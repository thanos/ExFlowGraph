defmodule ExFlow.StorageMockTest do
  use ExUnit.Case, async: true

  import Mox

  alias ExFlow.Core.Graph, as: FlowGraph
  alias ExFlow.Storage.Mock

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "mocking storage behaviour" do
    test "mocks save operation" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 100}})

      # Set expectation for save
      expect(Mock, :save, fn "test-graph", ^graph ->
        :ok
      end)

      # Call the mock
      assert :ok = Mock.save("test-graph", graph)
    end

    test "mocks load operation" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 100}})

      # Set expectation for load
      expect(Mock, :load, fn "test-graph" ->
        {:ok, graph}
      end)

      # Call the mock
      assert {:ok, loaded_graph} = Mock.load("test-graph")
      assert {:ok, _node} = FlowGraph.get_node(loaded_graph, "node-1")
    end

    test "mocks load error" do
      # Set expectation for load to return error
      expect(Mock, :load, fn "non-existent" ->
        {:error, :not_found}
      end)

      # Call the mock
      assert {:error, :not_found} = Mock.load("non-existent")
    end

    test "mocks delete operation" do
      # Set expectation for delete
      expect(Mock, :delete, fn "test-graph" ->
        :ok
      end)

      # Call the mock
      assert :ok = Mock.delete("test-graph")
    end

    test "mocks list operation" do
      # Set expectation for list
      expect(Mock, :list, fn ->
        ["graph-1", "graph-2", "graph-3"]
      end)

      # Call the mock
      assert ["graph-1", "graph-2", "graph-3"] = Mock.list()
    end

    test "mocks empty list" do
      expect(Mock, :list, fn -> [] end)
      assert [] = Mock.list()
    end

    test "mocks multiple operations in sequence" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 100}})

      # Expect save, then load, then delete
      expect(Mock, :save, fn "test-graph", ^graph -> :ok end)
      expect(Mock, :load, fn "test-graph" -> {:ok, graph} end)
      expect(Mock, :delete, fn "test-graph" -> :ok end)

      # Execute sequence
      assert :ok = Mock.save("test-graph", graph)
      assert {:ok, _} = Mock.load("test-graph")
      assert :ok = Mock.delete("test-graph")
    end

    test "allows multiple calls with stub" do
      graph = FlowGraph.new()

      # Stub allows unlimited calls
      stub(Mock, :save, fn _id, _graph -> :ok end)

      # Can call multiple times
      assert :ok = Mock.save("graph-1", graph)
      assert :ok = Mock.save("graph-2", graph)
      assert :ok = Mock.save("graph-3", graph)
    end

    test "verifies function was called correct number of times" do
      graph = FlowGraph.new()

      # Expect exactly 2 calls
      expect(Mock, :save, 2, fn _id, _graph -> :ok end)

      Mock.save("graph-1", graph)
      Mock.save("graph-2", graph)
      # verify_on_exit! will check that exactly 2 calls were made
    end

    test "mocks error scenarios" do
      # Mock save failure
      expect(Mock, :save, fn "error-graph", _graph ->
        {:error, :database_error}
      end)

      graph = FlowGraph.new()
      assert {:error, :database_error} = Mock.save("error-graph", graph)
    end
  end

  describe "testing code that uses storage" do
    defmodule GraphManager do
      def save_and_verify(storage, id, graph) do
        with :ok <- storage.save(id, graph),
             {:ok, loaded} <- storage.load(id) do
          {:ok, loaded}
        end
      end

      def safe_load(storage, id) do
        case storage.load(id) do
          {:ok, graph} -> {:ok, graph}
          {:error, :not_found} -> {:ok, FlowGraph.new()}
          {:error, reason} -> {:error, reason}
        end
      end
    end

    test "can test a function that depends on storage" do
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 100}})

      # Mock the storage behavior
      expect(Mock, :save, fn "test", ^graph -> :ok end)
      expect(Mock, :load, fn "test" -> {:ok, graph} end)

      # Test the function with mocked storage
      assert {:ok, result} = GraphManager.save_and_verify(Mock, "test", graph)
      assert {:ok, _} = FlowGraph.get_node(result, "node-1")
    end

    test "can test error handling with mocks" do
      # Mock not found scenario
      expect(Mock, :load, fn "missing" -> {:error, :not_found} end)
      assert {:ok, graph} = GraphManager.safe_load(Mock, "missing")
      assert Enum.empty?(FlowGraph.get_nodes(graph))

      # Mock other error scenario
      expect(Mock, :load, fn "error" -> {:error, :database_error} end)
      assert {:error, :database_error} = GraphManager.safe_load(Mock, "error")
    end
  end

  describe "advanced mocking patterns" do
    test "mocks with pattern matching on arguments" do
      graph1 = FlowGraph.new()
      {:ok, graph1} = FlowGraph.add_node(graph1, "node-1", :task, %{position: %{x: 100, y: 100}})

      graph2 = FlowGraph.new()
      {:ok, graph2} = FlowGraph.add_node(graph2, "node-2", :agent, %{position: %{x: 200, y: 200}})

      # Different behavior based on ID
      expect(Mock, :load, 3, fn
        "graph-1" -> {:ok, graph1}
        "graph-2" -> {:ok, graph2}
        _ -> {:error, :not_found}
      end)

      assert {:ok, g1} = Mock.load("graph-1")
      assert {:ok, _} = FlowGraph.get_node(g1, "node-1")

      assert {:ok, g2} = Mock.load("graph-2")
      assert {:ok, _} = FlowGraph.get_node(g2, "node-2")

      assert {:error, :not_found} = Mock.load("unknown")
    end

    test "mocks with state tracking" do
      # Use an Agent to track state across mock calls
      {:ok, agent} = Agent.start_link(fn -> %{} end)

      stub(Mock, :save, fn id, graph ->
        Agent.update(agent, &Map.put(&1, id, graph))
        :ok
      end)

      stub(Mock, :load, fn id ->
        case Agent.get(agent, &Map.get(&1, id)) do
          nil -> {:error, :not_found}
          graph -> {:ok, graph}
        end
      end)

      stub(Mock, :list, fn ->
        Agent.get(agent, &Map.keys(&1))
      end)

      # Use the stateful mock
      graph = FlowGraph.new()
      {:ok, graph} = FlowGraph.add_node(graph, "node-1", :task, %{position: %{x: 100, y: 100}})

      assert :ok = Mock.save("test", graph)
      assert {:ok, _} = Mock.load("test")
      assert ["test"] = Mock.list()

      Agent.stop(agent)
    end
  end
end
