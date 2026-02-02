defmodule ExFlow.Storage.InMemory do
  @moduledoc """
  In-memory graph storage adapter using an Elixir Agent.

  This adapter stores graphs in process memory using an Agent, making it
  suitable for development, testing, and applications that don't require
  persistence across server restarts.

  ## Features

  - Fast in-memory operations
  - No external dependencies
  - Automatic cleanup on application restart
  - Thread-safe via Agent serialization

  ## Limitations

  - Data is lost when the application restarts
  - Not suitable for distributed systems (single-node only)
  - Memory usage grows with number of stored graphs
  - No built-in expiration or cleanup

  ## Configuration

  This module is automatically started by the ExFlowGraph application
  supervisor. No additional configuration is required.

  ## Usage

      # Save a graph
      graph = ExFlow.Core.Graph.new()
      :ok = ExFlow.Storage.InMemory.save("my-workflow", graph)

      # Load a graph
      {:ok, graph} = ExFlow.Storage.InMemory.load("my-workflow")

      # List all graphs
      graph_ids = ExFlow.Storage.InMemory.list()
      # => ["my-workflow", "demo-graph"]

      # Delete a graph
      :ok = ExFlow.Storage.InMemory.delete("my-workflow")

  ## In LiveView

      defmodule MyAppWeb.FlowLive do
        use MyAppWeb, :live_view

        alias ExFlow.Storage.InMemory
        alias ExFlow.Core.Graph

        @storage_id "my-graph"

        def mount(_params, _session, socket) do
          graph =
            case InMemory.load(@storage_id) do
              {:ok, existing} -> existing
              {:error, :not_found} -> Graph.new()
            end

          {:ok, assign(socket, :graph, graph)}
        end

        def handle_event("update", params, socket) do
          graph = update_graph(socket.assigns.graph, params)
          :ok = InMemory.save(@storage_id, graph)
          {:noreply, assign(socket, :graph, graph)}
        end
      end

  ## Production Use

  For production applications requiring persistence, consider using
  `ExFlow.Storage.Ecto` or implementing a custom storage adapter that
  persists to your preferred database.
  """

  @behaviour ExFlow.Storage

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @impl true
  def load(id) do
    Agent.get(__MODULE__, fn state ->
      case Map.fetch(state, id) do
        {:ok, graph} -> {:ok, graph}
        :error -> {:error, :not_found}
      end
    end)
  end

  @impl true
  def save(id, graph) do
    Agent.update(__MODULE__, &Map.put(&1, id, graph))
    :ok
  end

  @impl true
  def delete(id) do
    Agent.get_and_update(__MODULE__, fn state ->
      case Map.has_key?(state, id) do
        true -> {:ok, Map.delete(state, id)}
        false -> {{:error, :not_found}, state}
      end
    end)
  end

  @impl true
  def list do
    Agent.get(__MODULE__, fn state ->
      Map.keys(state)
    end)
  end
end
