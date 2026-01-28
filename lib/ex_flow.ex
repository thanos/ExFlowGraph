defmodule ExFlow do
  @moduledoc """
  ExFlow - A simple and powerful library for building flow-based graphs.

  ExFlow provides an intuitive API for creating, manipulating, and persisting
  directed graphs with nodes and edges. Perfect for workflow engines, data pipelines,
  visual programming tools, and more.

  ## Quick Start

      # Create a new graph
      graph = ExFlow.new()

      # Add nodes
      {:ok, graph} = ExFlow.add_node(graph, "task-1", :task, x: 100, y: 100)
      {:ok, graph} = ExFlow.add_node(graph, "task-2", :task, x: 300, y: 100)

      # Connect nodes
      {:ok, graph} = ExFlow.add_edge(graph, "edge-1", "task-1", "task-2")

      # Get all nodes
      nodes = ExFlow.nodes(graph)

      # Save to storage
      :ok = ExFlow.save(graph, "my-workflow")

      # Load from storage
      {:ok, graph} = ExFlow.load("my-workflow")

  ## Builder Pattern

  For more complex graphs, use the builder pattern:

      graph =
        ExFlow.new()
        |> ExFlow.add_node!("start", :trigger, x: 0, y: 0, label: "Start")
        |> ExFlow.add_node!("process", :task, x: 200, y: 0, label: "Process Data")
        |> ExFlow.add_node!("end", :output, x: 400, y: 0, label: "End")
        |> ExFlow.add_edge!("e1", "start", "process")
        |> ExFlow.add_edge!("e2", "process", "end")

  ## Node Types

  ExFlow supports various node types:

  - `:task` - Processing nodes that perform work
  - `:trigger` - Entry points that start workflows
  - `:decision` - Conditional branching nodes
  - `:agent` - AI/autonomous processing nodes
  - `:output` - Terminal nodes that produce results
  - `:input` - Data input nodes

  ## Storage

  ExFlow supports multiple storage backends:

  - `ExFlow.Storage.InMemory` - Fast in-memory storage (development/testing)
  - `ExFlow.Storage.Ecto` - Database persistence with PostgreSQL

  Configure storage in your application:

      config :ex_flow, :storage, ExFlow.Storage.Ecto
      config :ex_flow, :repo, MyApp.Repo

  """

  alias ExFlow.Core.Graph

  @type graph :: Graph.t()
  @type node_id :: String.t()
  @type edge_id :: String.t()
  @type node_type :: atom()
  @type position_opts :: [x: number(), y: number()]
  @type metadata_opts :: keyword()

  # Graph Creation

  @doc """
  Creates a new empty graph.

  ## Examples

      iex> graph = ExFlow.new()
      iex> ExFlow.nodes(graph)
      []

  """
  @spec new() :: graph()
  def new, do: Graph.new()

  # Node Operations

  @doc """
  Adds a node to the graph with the given ID, type, and options.

  ## Options

  - `:x` - X coordinate (default: 0)
  - `:y` - Y coordinate (default: 0)
  - `:label` - Display label for the node
  - `:description` - Node description
  - Any other key-value pairs are stored in metadata

  ## Examples

      {:ok, graph} = ExFlow.add_node(graph, "task-1", :task, x: 100, y: 200)
      {:ok, graph} = ExFlow.add_node(graph, "task-2", :task, x: 300, y: 200, label: "Process")

  """
  @spec add_node(graph(), node_id(), node_type(), keyword()) :: {:ok, graph()} | {:error, term()}
  def add_node(graph, id, type, opts \\ []) do
    x = Keyword.get(opts, :x, 0)
    y = Keyword.get(opts, :y, 0)
    
    # Extract position and metadata
    {_pos_opts, metadata_opts} = Keyword.split(opts, [:x, :y])
    metadata = Map.new(metadata_opts)
    
    Graph.add_node(graph, id, type, %{
      position: %{x: x, y: y},
      metadata: metadata
    })
  end

  @doc """
  Adds a node to the graph, raising on error.

  Same as `add_node/4` but raises on error. Useful for builder pattern.

  ## Examples

      graph =
        ExFlow.new()
        |> ExFlow.add_node!("task-1", :task, x: 100, y: 100)
        |> ExFlow.add_node!("task-2", :task, x: 300, y: 100)

  """
  @spec add_node!(graph(), node_id(), node_type(), keyword()) :: graph()
  def add_node!(graph, id, type, opts \\ []) do
    case add_node(graph, id, type, opts) do
      {:ok, graph} -> graph
      {:error, reason} -> raise "Failed to add node: #{inspect(reason)}"
    end
  end

  @doc """
  Updates a node's position in the graph.

  ## Examples

      {:ok, graph} = ExFlow.move_node(graph, "task-1", 150, 250)

  """
  @spec move_node(graph(), node_id(), number(), number()) :: {:ok, graph()} | {:error, term()}
  def move_node(graph, id, x, y) do
    Graph.update_node_position(graph, id, x, y)
  end

  @doc """
  Removes a node from the graph.

  Also removes all edges connected to this node.

  ## Examples

      {:ok, graph} = ExFlow.delete_node(graph, "task-1")

  """
  @spec delete_node(graph(), node_id()) :: {:ok, graph()} | {:error, term()}
  def delete_node(graph, id) do
    Graph.delete_node(graph, id)
  end

  @doc """
  Gets a node by ID.

  ## Examples

      {:ok, node} = ExFlow.get_node(graph, "task-1")
      node.type  # => :task
      node.position  # => %{x: 100, y: 200}

  """
  @spec get_node(graph(), node_id()) :: {:ok, map()} | {:error, term()}
  def get_node(graph, id) do
    Graph.get_node(graph, id)
  end

  @doc """
  Returns all nodes in the graph.

  ## Examples

      nodes = ExFlow.nodes(graph)
      Enum.each(nodes, fn node ->
        IO.puts("\#{node.id}: \#{node.type}")
      end)

  """
  @spec nodes(graph()) :: [map()]
  def nodes(graph) do
    Graph.get_nodes(graph)
  end

  # Edge Operations

  @doc """
  Adds an edge connecting two nodes.

  By default, uses "out" and "in" handles. You can specify custom handles
  if needed.

  ## Examples

      # Simple edge
      {:ok, graph} = ExFlow.add_edge(graph, "edge-1", "task-1", "task-2")

      # Edge with custom handles
      {:ok, graph} = ExFlow.add_edge(graph, "edge-1", "task-1", "task-2", 
        source_handle: "success", target_handle: "input")

      # Edge with metadata
      {:ok, graph} = ExFlow.add_edge(graph, "edge-1", "task-1", "task-2",
        label: "On Success", weight: 5)

  """
  @spec add_edge(graph(), edge_id(), node_id(), node_id(), keyword()) ::
          {:ok, graph()} | {:error, term()}
  def add_edge(graph, id, source_id, target_id, opts \\ []) do
    source_handle = Keyword.get(opts, :source_handle, "out")
    target_handle = Keyword.get(opts, :target_handle, "in")
    
    # Extract metadata
    {_handle_opts, metadata_opts} = Keyword.split(opts, [:source_handle, :target_handle])
    metadata = Map.new(metadata_opts)
    
    Graph.add_edge(graph, id, source_id, source_handle, target_id, target_handle, metadata)
  end

  @doc """
  Adds an edge to the graph, raising on error.

  Same as `add_edge/5` but raises on error. Useful for builder pattern.

  ## Examples

      graph =
        ExFlow.new()
        |> ExFlow.add_node!("task-1", :task)
        |> ExFlow.add_node!("task-2", :task)
        |> ExFlow.add_edge!("edge-1", "task-1", "task-2")

  """
  @spec add_edge!(graph(), edge_id(), node_id(), node_id(), keyword()) :: graph()
  def add_edge!(graph, id, source_id, target_id, opts \\ []) do
    case add_edge(graph, id, source_id, target_id, opts) do
      {:ok, graph} -> graph
      {:error, reason} -> raise "Failed to add edge: #{inspect(reason)}"
    end
  end

  @doc """
  Removes an edge from the graph.

  ## Examples

      {:ok, graph} = ExFlow.delete_edge(graph, "edge-1")

  """
  @spec delete_edge(graph(), edge_id()) :: {:ok, graph()} | {:error, term()}
  def delete_edge(graph, id) do
    Graph.delete_edge(graph, id)
  end

  @doc """
  Returns all edges in the graph.

  ## Examples

      edges = ExFlow.edges(graph)
      Enum.each(edges, fn edge ->
        IO.puts("\#{edge.source} -> \#{edge.target}")
      end)

  """
  @spec edges(graph()) :: [map()]
  def edges(graph) do
    Graph.get_edges(graph)
  end

  # Serialization

  @doc """
  Converts a graph to a map for serialization.

  ## Examples

      map = ExFlow.to_map(graph)
      # %{nodes: [...], edges: [...]}

  """
  @spec to_map(graph()) :: map()
  def to_map(graph) do
    Graph.to_map(graph)
  end

  @doc """
  Creates a graph from a map.

  ## Examples

      {:ok, graph} = ExFlow.from_map(%{
        nodes: [
          %{id: "task-1", type: :task, position: %{x: 0, y: 0}, metadata: %{}}
        ],
        edges: []
      })

  """
  @spec from_map(map()) :: {:ok, graph()} | {:error, term()}
  def from_map(map) do
    Graph.from_map(map)
  end

  # Storage Operations

  @doc """
  Saves a graph to the configured storage backend.

  ## Examples

      :ok = ExFlow.save(graph, "my-workflow")

  """
  @spec save(graph(), String.t()) :: :ok | {:error, term()}
  def save(graph, name) when is_binary(name) do
    storage().save(name, graph)
  end

  @doc """
  Loads a graph from the configured storage backend.

  ## Examples

      {:ok, graph} = ExFlow.load("my-workflow")

  """
  @spec load(String.t()) :: {:ok, graph()} | {:error, term()}
  def load(name) when is_binary(name) do
    storage().load(name)
  end

  @doc """
  Deletes a graph from storage.

  ## Examples

      :ok = ExFlow.delete("my-workflow")

  """
  @spec delete(String.t()) :: :ok | {:error, term()}
  def delete(name) when is_binary(name) do
    storage().delete(name)
  end

  @doc """
  Lists all saved graphs.

  ## Examples

      graphs = ExFlow.list()
      # ["workflow-1", "workflow-2", "workflow-3"]

  """
  @spec list() :: [String.t()]
  def list do
    storage().list()
  end

  # Private Helpers

  defp storage do
    Application.get_env(:ex_flow, :storage, ExFlow.Storage.InMemory)
  end
end
