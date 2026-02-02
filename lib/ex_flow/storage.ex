defmodule ExFlow.Storage do
  @moduledoc """
  Behaviour for implementing graph storage adapters.

  Storage adapters provide a pluggable backend for persisting and retrieving
  flow graphs. This allows applications to choose between different storage
  mechanisms (in-memory, database, file system, etc.) without changing the
  core graph logic.

  ## Callbacks

  All storage adapters must implement four callbacks:

  - `c:load/1` - Retrieve a graph by ID
  - `c:save/2` - Persist a graph with an ID
  - `c:delete/1` - Remove a graph by ID
  - `c:list/0` - List all stored graph IDs

  ## Built-in Adapters

  - `ExFlow.Storage.InMemory` - Agent-based in-memory storage (included)
  - `ExFlow.Storage.Ecto` - Database storage via Ecto (separate package)

  ## Example Implementation

      defmodule MyApp.GraphStorage do
        @behaviour ExFlow.Storage

        @impl true
        def load(id) do
          case MyApp.Repo.get(Graph, id) do
            nil -> {:error, :not_found}
            graph -> {:ok, graph.data}
          end
        end

        @impl true
        def save(id, graph) do
          %Graph{id: id, data: graph}
          |> MyApp.Repo.insert_or_update()
          |> case do
            {:ok, _} -> :ok
            {:error, reason} -> {:error, reason}
          end
        end

        @impl true
        def delete(id) do
          case MyApp.Repo.get(Graph, id) do
            nil -> {:error, :not_found}
            graph -> MyApp.Repo.delete(graph)
          end
        end

        @impl true
        def list do
          MyApp.Repo.all(from g in Graph, select: g.id)
        end
      end

  ## Usage in LiveView

      def mount(_params, _session, socket) do
        graph =
          case MyStorage.load("my-graph-id") do
            {:ok, graph} -> graph
            {:error, :not_found} -> ExFlow.Core.Graph.new()
          end

        {:ok, assign(socket, :graph, graph)}
      end

      def handle_event("update_position", params, socket) do
        graph = update_graph(socket.assigns.graph, params)
        :ok = MyStorage.save("my-graph-id", graph)
        {:noreply, assign(socket, :graph, graph)}
      end
  """

  @callback load(id :: String.t()) :: {:ok, any()} | {:error, term()}
  @callback save(id :: String.t(), graph :: any()) :: :ok | {:error, term()}
  @callback delete(id :: String.t()) :: :ok | {:error, term()}
  @callback list() :: [String.t()]
end
