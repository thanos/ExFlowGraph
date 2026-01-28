# ExFlow Usage Guide

This guide provides a comprehensive overview of the `ex_flow` component, its architecture, and how to use it effectively in your Elixir applications.

## 1. High-Level Overview

`ex_flow` is a powerful Elixir library for building and managing graph-based data structures. It provides a flexible and extensible foundation for a wide range of applications, including:

*   Workflow and pipeline management
*   State machine implementation
*   Interactive graph editors
*   Data visualization tools

At its core, `ex_flow` is a wrapper around the `libgraph` library, providing a higher-level API and a set of conventions for working with graphs. It introduces several key features on top of `libgraph`, including:

*   **Pluggable Storage:** `ex_flow` allows you to store your graphs in different backends. It comes with a default in-memory storage adapter for development and testing, and an Ecto-based adapter for production use with a database.
*   **Serialization:** A built-in serializer converts graph data to and from a JSON-compatible format, making it easy to store in a database or transmit over the network.
*   **Undo/Redo:** The library includes a command pattern implementation for adding undo and redo functionality to your graph editor.
*   **Rich Node and Edge Data:** `ex_flow` allows you to attach arbitrary metadata to your nodes and edges, making it easy to store application-specific data.

## 2. Architecture

The `ex_flow` library is composed of several key modules:

*   **`ExFlow`:** The main public API for interacting with the library.
*   **`ExFlow.Core.Graph`:** The core data structure, which is a wrapper around a `LibGraph` struct. It defines the schema for nodes and edges.
*   **`ExFlow.Storage`:** A behaviour that defines the interface for storage adapters.
*   **`ExFlow.Storage.InMemory`:** An in-memory storage adapter that uses an `Agent` to store the graph.
*   **`ExFlow.Storage.Ecto`:** An Ecto-based storage adapter for persisting graphs to a database.
*   **`ExFlow.GraphRecord`:** The Ecto schema for the `graphs` table.
*   **`ExFlow.Serializer`:** The module responsible for serializing and deserializing graph data.
*   **`ExFlow.Command`:** A protocol for defining undoable commands.
*   **`ExFlow.HistoryManager`:** A manager for handling undo and redo operations.

The following diagram illustrates the high-level architecture of `ex_flow`:

```
+---------------------------+
|   Your Application Logic  |
+---------------------------+
      |
      v
+---------------------------+
|        ExFlow API         |
+---------------------------+
      |
      v
+---------------------------+
|    ExFlow.Core.Graph      |
+---------------------------+
      |                 ^
      v                 |
+---------------------------+
|     ExFlow.Storage        |
+---------------------------+
      |                 ^
      |                 |
+------------------+ +------------------+
| ExFlow.Storage.  | | ExFlow.Storage.  |
| InMemory         | | Ecto             |
+------------------+ +------------------+
                        |
                        v
+---------------------------+
|      ExFlow.Serializer    |
+---------------------------+
                        |
                        v
+---------------------------+
|    ExFlow.GraphRecord     |
+---------------------------+
                        |
                        v
+---------------------------+
|        Database           |
+---------------------------+
```

In the next sections, we will dive deeper into each of these modules and provide practical examples of how to use them.

## 3. Core Concepts and Essential Functions

This section provides a detailed breakdown of the essential functions and modules in `ex_flow`.

### 3.1. The `ExFlow` Module

The `ExFlow` module is the main entry point for interacting with the library. It provides a simple and consistent API for creating, loading, and saving graphs.

```elixir
# Create a new, empty graph
{:ok, graph} = ExFlow.new()

# Add a node to the graph
{:ok, graph} = ExFlow.add_node(graph, "node-1", :my_type, %{x: 10, y: 20})

# Add an edge to the graph
{:ok, graph} = ExFlow.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in")

# Save the graph using the default storage adapter
:ok = ExFlow.save("my-graph", graph)

# Load the graph from storage
{:ok, graph} = ExFlow.load("my-graph")
```

### 3.2. The `ExFlow.Core.Graph` Module

The `ExFlow.Core.Graph` module provides the core data structure for graphs. It's a wrapper around `LibGraph` and defines the structure of nodes and edges.

#### Nodes

A node is a map with the following keys:

*   `:id`: A unique identifier for the node (string).
*   `:type`: The type of the node (atom).
*   `:position`: A map with `:x` and `:y` coordinates.
*   `:metadata`: A map for storing arbitrary data.

#### Edges

An edge is a map with the following keys:

*   `:id`: A unique identifier for the edge (string).
*   `:source`: The ID of the source node.
*   `:source_handle`: The handle on the source node (e.g., "out").
*   `:target`: The ID of the target node.
*   `:target_handle`: The handle on the target node (e.g., "in").

### 3.3. Storage Adapters

`ex_flow`'s pluggable storage system is one of its key features. You can configure your application to use different storage backends in different environments.

To configure a storage adapter, you need to add it to your application's configuration:

```elixir
# config/config.exs
config :ex_flow,
  storage: ExFlow.Storage.InMemory

# For production, you might use the Ecto adapter:
# config/prod.exs
config :ex_flow,
  storage: ExFlow.Storage.Ecto,
  repo: MyApp.Repo
```

#### `ExFlow.Storage.InMemory`

This is the default storage adapter. It's a simple, `Agent`-based store that's great for development and testing.

#### `ExFlow.Storage.Ecto`

This adapter allows you to persist your graphs in a database. To use it, you need to create a migration for the `graphs` table.

```elixir
# priv/repo/migrations/create_graphs_table.exs
defmodule MyApp.Repo.Migrations.CreateGraphsTable do
  use Ecto.Migration

  def change do
    create table(:graphs) do
      add :name, :string, null: false
      add :data, :map, null: false
      add :version, :integer, default: 1
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()

      create index(:graphs, [:name, :user_id], unique: true)
    end
  end
end
```

You'll also need to define a `ExFlow.GraphRecord` module in your application that uses the `ExFlow.GraphRecord` schema.

### 3.4. Undo/Redo with `ExFlow.HistoryManager`

The `ExFlow.HistoryManager` allows you to add undo and redo functionality to your application. It works by wrapping your graph modifications in `ExFlow.Command` structs.

While a full implementation is beyond the scope of this guide, here's a conceptual overview:

```elixir
# 1. Define your commands
defmodule MyApp.Commands.MoveNode do
  @behaviour ExFlow.Command

  defstruct [:node_id, :old_position, :new_position]

  def execute(command, graph) do
    ExFlow.Core.Graph.update_node_position(graph, command.node_id, command.new_position)
  end

  def undo(command, graph) do
    ExFlow.Core.Graph.update_node_position(graph, command.node_id, command.old_position)
  end

  def description(_), do: "Move Node"
end

# 2. Use the HistoryManager
history = ExFlow.HistoryManager.new()
{:ok, history, graph} = ExFlow.HistoryManager.execute(history, %MyApp.Commands.MoveNode{...}, graph)

# 3. Undo and redo
{:ok, history, graph} = ExFlow.HistoryManager.undo(history, graph)
{:ok, history, graph} = ExFlow.HistoryManager.redo(history, graph)
```

## 4. Demo Application Walkthrough

The demo application included in the repository is a great way to see `ex_flow` in action. It's a simple Phoenix LiveView application that allows you to create, move, and connect nodes in a graph.

### 4.1. Structure

The demo application is a standard Phoenix application. The most relevant files for understanding the `ex_flow` integration are:

*   `demo/lib/ex_flow_graph_web/live/flow_live.ex`: The main LiveView that manages the graph state.
*   `demo/lib/ex_flow_graph_web/components/ex_flow/canvas.ex`: The LiveComponent that renders the graph.
*   `demo/lib/ex_flow_graph_web/components/ex_flow/ex_flow.js`: The JavaScript hook that handles user interactions.

### 4.2. `FlowLive` - The State Manager

The `FlowLive` module is the heart of the demo application. It's responsible for:

*   **Loading the graph:** In the `mount/3` callback, it loads the graph from the `InMemory` storage. If no graph is found, it creates a new one with some default nodes and edges.
*   **Handling events:** It handles events from the client, such as `"update_position"` and `"create_edge"`.
*   **Updating the graph:** When an event is received, it uses `ExFlow.Core.Graph` functions to update the graph state.
*   **Saving the graph:** After each update, it saves the graph back to the `InMemory` storage.
*   **Rendering the UI:** It passes the graph data to the `canvas` component for rendering.

Here's a snippet from `flow_live.ex` that shows how it handles the `"update_position"` event:

```elixir
def handle_event("update_position", %{"id" => id, "x" => x, "y" => y}, socket) do
  case FlowGraph.update_node_position(socket.assigns.graph, id, %{x: round(x), y: round(y)}) do
    {:ok, graph} ->
      :ok = InMemory.save(@storage_id, graph)
      {:noreply, assign(socket, :graph, graph)}

    {:error, _reason} ->
      {:noreply, socket}
  end
end
```

### 4.3. `Canvas` - The Renderer

The `canvas` component is a stateless LiveComponent that's responsible for rendering the graph. It receives the `nodes` and `edges` from the `FlowLive` LiveView and renders them as HTML and SVG.

It also includes the `phx-hook="ExFlowCanvas"` attribute, which tells Phoenix to attach the JavaScript hook defined in `ex_flow.js`.

### 4.4. `ExFlowCanvas` - The Interaction Handler

The `ex_flow.js` file contains a small JavaScript hook that handles user interactions on the client side. It's responsible for:

*   **Dragging nodes:** It listens for `mousedown`, `mousemove`, and `mouseup` events to allow users to drag nodes around the canvas.
*   **Updating node positions:** As a node is dragged, it updates its position in the DOM.
*   **Sending events to the server:** When a node is dropped, it sends an `"update_position"` event to the `FlowLive` LiveView with the new coordinates.
*   **Updating edges:** It also updates the connected edges in the SVG canvas as the node is being dragged.

This combination of a stateful LiveView, a stateless LiveComponent, and a small JavaScript hook is a powerful pattern for building interactive UIs with Phoenix LiveView.



## 5. Practical Usage Examples & Best Practices



Beyond the demo, here are some other common patterns and best practices for using `ex_flow`.



### 5.1. Working with Node Metadata



You can store any kind of application-specific data in the `metadata` field of a node. For example, you could use it to store user input, validation rules, or the status of a task.



```elixir

# Add a node with some metadata

{:ok, graph} = ExFlow.add_node(graph, "task-1", :task, %{x: 10, y: 20}, %{

  title: "My First Task",

  status: :pending,

  retries: 0

})



# Later, update the metadata

{:ok, graph} = ExFlow.Core.Graph.update_node_metadata(graph, "task-1", fn metadata ->

  Map.put(metadata, :status, :completed)

end)

```



### 5.2. Graph Traversal and Analysis



`ex_flow` is built on top of `libgraph`, so you can use all of `libgraph`'s powerful traversal and analysis functions.



```elixir

# Get all the nodes in the graph

nodes = LibGraph.vertices(graph)



# Get the neighbors of a node

neighbors = LibGraph.neighbors(graph, "node-1")



# Find a path between two nodes

path = LibGraph.path(graph, "node-1", "node-5")



# Check for cycles

has_cycle? = LibGraph.has_cycle?(graph)

```



### 5.3. Custom Storage Adapters



If you need to store your graphs in a different backend (e.g., Redis, a file on disk), you can create your own storage adapter. You just need to implement the `ExFlow.Storage` behaviour.



```elixir

defmodule MyApp.Storage.File do

  @behaviour ExFlow.Storage



  def load(id) do

    # ... read from file

  end



  def save(id, graph) do

    # ... write to file

  end



  def delete(id) do

    # ... delete file

  end



  def list do

    # ... list files

  end

end

```



### 5.4. Optimistic Locking



When using the `Ecto` storage adapter, `ex_flow` automatically enables optimistic locking. This is a crucial feature for preventing race conditions in a concurrent environment.



When you load a graph, it comes with a `version` number. When you save it, `ex_flow` checks that the `version` number in the database is the same as the one you have. If it's not, it means someone else has modified the graph in the meantime, and the save will fail.



You should handle this case in your application by reloading the graph and reapplying your changes.

## 6. Troubleshooting & Common Pitfalls

Here are some common issues you might encounter when working with `ex_flow`.

*   **`stale entry` error when saving:** This error occurs when you try to save a graph with an outdated version number. It's a result of the optimistic locking mechanism. To resolve this, you need to reload the latest version of the graph, re-apply your changes, and then try saving again.

*   **`no function clause matching` errors with `ExFlow.Serializer`:** This usually happens when the data you're trying to deserialize doesn't match the expected format. Make sure your data has `nodes` and `edges` keys, and that the nodes and edges themselves have the correct structure.

*   **Performance issues with large graphs:** While `libgraph` is very efficient, rendering a large number of nodes and edges in the browser can be slow. If you're working with large graphs, consider implementing a "virtualization" strategy, where you only render the nodes and edges that are currently visible in the viewport.

*   **Incorrectly configured storage:** If you're having trouble loading or saving graphs, double-check your storage configuration in `config/config.exs`. Make sure you've specified the correct adapter and, if you're using the `Ecto` adapter, that you've provided the correct `repo`.

By keeping these points in mind, you can avoid common pitfalls and build robust, scalable applications with `ex_flow`.

