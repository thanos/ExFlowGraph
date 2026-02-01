# Events and Callbacks Reference

This guide provides a comprehensive reference of all events and callbacks in ExFlowGraph, with complete examples for each.

## Core Canvas Events

These events are automatically triggered by the ExFlowCanvas JavaScript hook and should be handled in your LiveView.

### update_position

Fired when a node is dragged to a new position.

**Parameters:**
- `id` (string) - The node ID
- `x` (number) - New X coordinate
- `y` (number) - New Y coordinate

**Example:**

```elixir
@impl true
def handle_event("update_position", %{"id" => id, "x" => x, "y" => y}, socket) do
  case ExFlow.Core.Graph.update_node_position(socket.assigns.graph, id, %{x: x, y: y}) do
    {:ok, graph} ->
      # Optional: Save to storage
      :ok = ExFlow.Storage.InMemory.save(@storage_id, graph)
      {:noreply, assign(socket, :graph, graph)}

    {:error, _reason} ->
      {:noreply, socket}
  end
end
```

**With History (Recommended):**

```elixir
@impl true
def handle_event("update_position", %{"id" => id, "x" => x, "y" => y}, socket) do
  command = ExFlow.Commands.MoveNodeCommand.new(id, %{x: x, y: y})

  case ExFlow.HistoryManager.execute(socket.assigns.history, command, socket.assigns.graph) do
    {:ok, history, graph} ->
      :ok = ExFlow.Storage.InMemory.save(@storage_id, graph)
      {:noreply, assign(socket, history: history, graph: graph)}

    {:error, _reason} ->
      {:noreply, socket}
  end
end
```

### create_edge

Fired when a user drags from a source handle to a target handle to create an edge.

**Parameters:**
- `source_id` (string) - Source node ID
- `source_handle` (string) - Source handle name (e.g., "out")
- `target_id` (string) - Target node ID
- `target_handle` (string) - Target handle name (e.g., "in")

**Example:**

```elixir
@impl true
def handle_event("create_edge", params, socket) do
  %{
    "source_id" => source_id,
    "source_handle" => source_handle,
    "target_id" => target_id,
    "target_handle" => target_handle
  } = params

  edge_id = "edge-#{System.unique_integer([:positive])}"

  case ExFlow.Core.Graph.add_edge(
    socket.assigns.graph,
    edge_id,
    source_id,
    source_handle,
    target_id,
    target_handle
  ) do
    {:ok, graph} ->
      :ok = ExFlow.Storage.InMemory.save(@storage_id, graph)
      {:noreply, assign(socket, :graph, graph)}

    {:error, _reason} ->
      {:noreply, socket}
  end
end
```

**With History and Metadata:**

```elixir
@impl true
def handle_event("create_edge", params, socket) do
  %{
    "source_id" => source_id,
    "source_handle" => source_handle,
    "target_id" => target_id,
    "target_handle" => target_handle
  } = params

  edge_id = "edge-#{System.unique_integer([:positive])}"

  command = ExFlow.Commands.CreateEdgeCommand.new(
    edge_id,
    source_id,
    source_handle,
    target_id,
    target_handle,
    %{
      label: "connection",
      metadata: %{created_at: DateTime.utc_now()}
    }
  )

  case ExFlow.HistoryManager.execute(socket.assigns.history, command, socket.assigns.graph) do
    {:ok, history, graph} ->
      :ok = ExFlow.Storage.InMemory.save(@storage_id, graph)
      {:noreply, assign(socket, history: history, graph: graph)}

    {:error, _reason} ->
      {:noreply, socket}
  end
end
```

### select_node

Fired when a node is clicked (without Option/Alt key).

**Parameters:**
- `id` (string) - Node ID
- `multi` (string) - "true" if Shift/Ctrl/Cmd was pressed, "false" otherwise

**Example:**

```elixir
@impl true
def handle_event("select_node", %{"id" => id, "multi" => multi}, socket) do
  selected =
    if multi == "true" do
      # Multi-select: toggle the node in selection
      toggle_selection(socket.assigns.selected_node_ids, id)
    else
      # Single select: replace selection
      MapSet.new([id])
    end

  {:noreply, assign(socket, :selected_node_ids, selected)}
end

defp toggle_selection(set, id) do
  if MapSet.member?(set, id) do
    MapSet.delete(set, id)
  else
    MapSet.put(set, id)
  end
end
```

**With Edge Deselection:**

```elixir
@impl true
def handle_event("select_node", %{"id" => id, "multi" => multi}, socket) do
  selected_nodes =
    if multi == "true" do
      toggle_selection(socket.assigns.selected_node_ids, id)
    else
      MapSet.new([id])
    end

  socket =
    socket
    |> assign(:selected_node_ids, selected_nodes)
    |> assign(:selected_edge_ids, MapSet.new())  # Clear edge selection

  {:noreply, socket}
end
```

### select_edge

Fired when an edge is clicked (without Option/Alt key).

**Parameters:**
- `id` (string) - Edge ID
- `multi` (string) - "true" if Shift/Ctrl/Cmd was pressed, "false" otherwise

**Example:**

```elixir
@impl true
def handle_event("select_edge", %{"id" => id, "multi" => multi}, socket) do
  selected =
    if multi == "true" do
      toggle_selection(socket.assigns.selected_edge_ids, id)
    else
      MapSet.new([id])
    end

  {:noreply, assign(socket, :selected_edge_ids, selected)}
end
```

**With Node Deselection:**

```elixir
@impl true
def handle_event("select_edge", %{"id" => id, "multi" => multi}, socket) do
  selected_edges =
    if multi == "true" do
      toggle_selection(socket.assigns.selected_edge_ids, id)
    else
      MapSet.new([id])
    end

  socket =
    socket
    |> assign(:selected_edge_ids, selected_edges)
    |> assign(:selected_node_ids, MapSet.new())  # Clear node selection

  {:noreply, socket}
end
```

### option_click_node

Fired when a node is clicked while holding Option/Alt key.

**Parameters:**
- `id` (string) - Node ID

**Example - Show Details:**

```elixir
@impl true
def handle_event("option_click_node", %{"id" => id}, socket) do
  node = ExFlow.Core.Graph.get_nodes(socket.assigns.graph)
         |> Enum.find(&(&1.id == id))

  if node do
    IO.inspect(node, label: "Node Details")
    {:noreply, socket}
  else
    {:noreply, socket}
  end
end
```

**Example - Open Edit Modal:**

```elixir
@impl true
def handle_event("option_click_node", %{"id" => id}, socket) do
  node = ExFlow.Core.Graph.get_nodes(socket.assigns.graph)
         |> Enum.find(&(&1.id == id))

  if node do
    metadata_json = Jason.encode!(node.metadata, pretty: true)

    socket =
      socket
      |> assign(:show_edit_modal, true)
      |> assign(:editing_type, :node)
      |> assign(:editing_item, node)
      |> assign(:edit_label, node.label || "")
      |> assign(:edit_metadata, metadata_json)

    {:noreply, socket}
  else
    {:noreply, socket}
  end
end
```

**Example - Quick Delete:**

```elixir
@impl true
def handle_event("option_click_node", %{"id" => id}, socket) do
  command = ExFlow.Commands.DeleteNodeCommand.new(id)

  case ExFlow.HistoryManager.execute(socket.assigns.history, command, socket.assigns.graph) do
    {:ok, history, graph} ->
      socket =
        socket
        |> assign(history: history, graph: graph)
        |> assign(:selected_node_ids, MapSet.delete(socket.assigns.selected_node_ids, id))

      {:noreply, socket}

    {:error, _reason} ->
      {:noreply, socket}
  end
end
```

### option_click_edge

Fired when an edge is clicked while holding Option/Alt key.

**Parameters:**
- `id` (string) - Edge ID

**Example - Show Details:**

```elixir
@impl true
def handle_event("option_click_edge", %{"id" => id}, socket) do
  edge = ExFlow.Core.Graph.get_edges(socket.assigns.graph)
         |> Enum.find(&(&1.id == id))

  if edge do
    IO.inspect(edge, label: "Edge Details")
    {:noreply, socket}
  else
    {:noreply, socket}
  end
end
```

**Example - Open Edit Modal:**

```elixir
@impl true
def handle_event("option_click_edge", %{"id" => id}, socket) do
  edge = ExFlow.Core.Graph.get_edges(socket.assigns.graph)
         |> Enum.find(&(&1.id == id))

  if edge do
    metadata_json = Jason.encode!(edge.metadata, pretty: true)

    socket =
      socket
      |> assign(:show_edit_modal, true)
      |> assign(:editing_type, :edge)
      |> assign(:editing_item, edge)
      |> assign(:edit_label, edge.label || "")
      |> assign(:edit_metadata, metadata_json)

    {:noreply, socket}
  else
    {:noreply, socket}
  end
end
```

**Example - Quick Delete:**

```elixir
@impl true
def handle_event("option_click_edge", %{"id" => id}, socket) do
  command = ExFlow.Commands.DeleteEdgeCommand.new(id)

  case ExFlow.HistoryManager.execute(socket.assigns.history, command, socket.assigns.graph) do
    {:ok, history, graph} ->
      socket =
        socket
        |> assign(history: history, graph: graph)
        |> assign(:selected_edge_ids, MapSet.delete(socket.assigns.selected_edge_ids, id))

      {:noreply, socket}

    {:error, _reason} ->
      {:noreply, socket}
  end
end
```

## Keyboard Events

Handle keyboard shortcuts for common operations.

### key_down

Generic keyboard event handler that you can use for any keyboard shortcuts.

**Parameters:**
- `key` (string) - The key that was pressed
- `meta` (boolean) - True if Cmd (Mac) or Ctrl (Windows/Linux) was pressed
- `shift` (boolean) - True if Shift was pressed
- `alt` (boolean) - True if Alt/Option was pressed

**Setup in Template:**

```heex
<div phx-window-keydown="key_down">
  <!-- Your canvas and other content -->
</div>
```

**Example - Undo/Redo:**

```elixir
@impl true
def handle_event("key_down", %{"key" => "z", "meta" => true, "shift" => true}, socket) do
  # Cmd/Ctrl + Shift + Z = Redo
  case ExFlow.HistoryManager.redo(socket.assigns.history, socket.assigns.graph) do
    {:ok, history, graph} ->
      {:noreply, assign(socket, history: history, graph: graph)}

    {:error, :nothing_to_redo} ->
      {:noreply, socket}
  end
end

def handle_event("key_down", %{"key" => "z", "meta" => true}, socket) do
  # Cmd/Ctrl + Z = Undo
  case ExFlow.HistoryManager.undo(socket.assigns.history, socket.assigns.graph) do
    {:ok, history, graph} ->
      {:noreply, assign(socket, history: history, graph: graph)}

    {:error, :nothing_to_undo} ->
      {:noreply, socket}
  end
end

def handle_event("key_down", %{"key" => "y", "meta" => true}, socket) do
  # Cmd/Ctrl + Y = Redo (alternative)
  case ExFlow.HistoryManager.redo(socket.assigns.history, socket.assigns.graph) do
    {:ok, history, graph} ->
      {:noreply, assign(socket, history: history, graph: graph)}

    {:error, :nothing_to_redo} ->
      {:noreply, socket}
  end
end

def handle_event("key_down", _params, socket) do
  # Catch-all for unhandled keys
  {:noreply, socket}
end
```

**Example - Delete Selected:**

```elixir
def handle_event("key_down", %{"key" => "Delete"}, socket) do
  delete_selected(socket)
end

def handle_event("key_down", %{"key" => "Backspace"}, socket) do
  delete_selected(socket)
end

defp delete_selected(socket) do
  # Delete selected nodes
  node_commands =
    socket.assigns.selected_node_ids
    |> Enum.map(&ExFlow.Commands.DeleteNodeCommand.new/1)

  # Delete selected edges
  edge_commands =
    socket.assigns.selected_edge_ids
    |> Enum.map(&ExFlow.Commands.DeleteEdgeCommand.new/1)

  commands = node_commands ++ edge_commands

  if Enum.empty?(commands) do
    {:noreply, socket}
  else
    # Execute all deletions as a batch
    batch_command = BatchCommand.new(commands, "Delete selected items")

    case ExFlow.HistoryManager.execute(socket.assigns.history, batch_command, socket.assigns.graph) do
      {:ok, history, graph} ->
        socket =
          socket
          |> assign(history: history, graph: graph)
          |> assign(:selected_node_ids, MapSet.new())
          |> assign(:selected_edge_ids, MapSet.new())

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end
end
```

**Example - Select All:**

```elixir
def handle_event("key_down", %{"key" => "a", "meta" => true}, socket) do
  # Cmd/Ctrl + A = Select All Nodes
  all_node_ids =
    socket.assigns.graph
    |> ExFlow.Core.Graph.get_nodes()
    |> Enum.map(& &1.id)
    |> MapSet.new()

  {:noreply, assign(socket, :selected_node_ids, all_node_ids)}
end
```

**Example - Escape to Deselect:**

```elixir
def handle_event("key_down", %{"key" => "Escape"}, socket) do
  socket =
    socket
    |> assign(:selected_node_ids, MapSet.new())
    |> assign(:selected_edge_ids, MapSet.new())

  {:noreply, socket}
end
```

**Example - Copy/Paste:**

```elixir
def handle_event("key_down", %{"key" => "c", "meta" => true}, socket) do
  # Copy selected nodes
  selected_nodes =
    socket.assigns.graph
    |> ExFlow.Core.Graph.get_nodes()
    |> Enum.filter(&MapSet.member?(socket.assigns.selected_node_ids, &1.id))

  {:noreply, assign(socket, :clipboard, selected_nodes)}
end

def handle_event("key_down", %{"key" => "v", "meta" => true}, socket) do
  # Paste nodes from clipboard
  if socket.assigns[:clipboard] do
    # Create new nodes with offset positions
    commands =
      socket.assigns.clipboard
      |> Enum.map(fn node ->
        new_id = "node-#{System.unique_integer([:positive])}"
        new_position = %{
          x: node.position.x + 20,
          y: node.position.y + 20
        }
        metadata = Map.put(node.metadata, :position, new_position)

        ExFlow.Commands.CreateNodeCommand.new(new_id, node.type, metadata)
      end)

    batch_command = BatchCommand.new(commands, "Paste nodes")

    case ExFlow.HistoryManager.execute(socket.assigns.history, batch_command, socket.assigns.graph) do
      {:ok, history, graph} ->
        {:noreply, assign(socket, history: history, graph: graph)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  else
    {:noreply, socket}
  end
end
```

## User Action Events

Custom events you implement for user actions like toolbar buttons.

### add_node

Add a new node to the graph.

**Example:**

```elixir
@impl true
def handle_event("add_node", %{"type" => type_string}, socket) do
  type = String.to_existing_atom(type_string)
  node_id = "node-#{System.unique_integer([:positive])}"

  # Calculate position (center of viewport or random)
  position = %{
    x: 100 + :rand.uniform(200),
    y: 100 + :rand.uniform(200)
  }

  command = ExFlow.Commands.CreateNodeCommand.new(
    node_id,
    type,
    %{
      position: position,
      label: "New #{type}",
      metadata: %{}
    }
  )

  case ExFlow.HistoryManager.execute(socket.assigns.history, command, socket.assigns.graph) do
    {:ok, history, graph} ->
      {:noreply, assign(socket, history: history, graph: graph)}

    {:error, _reason} ->
      {:noreply, socket}
  end
end
```

### delete_selected

Delete all selected nodes and edges.

**Example:**

```elixir
@impl true
def handle_event("delete_selected", _params, socket) do
  # Implementation same as in keyboard events above
  delete_selected(socket)
end
```

### undo

Undo the last operation.

**Example:**

```elixir
@impl true
def handle_event("undo", _params, socket) do
  case ExFlow.HistoryManager.undo(socket.assigns.history, socket.assigns.graph) do
    {:ok, history, graph} ->
      {:noreply, assign(socket, history: history, graph: graph)}

    {:error, :nothing_to_undo} ->
      {:noreply, socket}
  end
end
```

### redo

Redo the last undone operation.

**Example:**

```elixir
@impl true
def handle_event("redo", _params, socket) do
  case ExFlow.HistoryManager.redo(socket.assigns.history, socket.assigns.graph) do
    {:ok, history, graph} ->
      {:noreply, assign(socket, history: history, graph: graph)}

    {:error, :nothing_to_redo} ->
      {:noreply, socket}
  end
end
```

### save_graph

Save the current graph to storage.

**Example:**

```elixir
@impl true
def handle_event("save_graph", %{"name" => name}, socket) do
  case ExFlow.Storage.InMemory.save(name, socket.assigns.graph) do
    :ok ->
      socket =
        socket
        |> put_flash(:info, "Graph saved as '#{name}'")
        |> assign(:current_graph_name, name)

      {:noreply, socket}

    {:error, reason} ->
      {:noreply, put_flash(socket, :error, "Failed to save: #{inspect(reason)}")}
  end
end
```

### load_graph

Load a graph from storage.

**Example:**

```elixir
@impl true
def handle_event("load_graph", %{"name" => name}, socket) do
  case ExFlow.Storage.InMemory.load(name) do
    {:ok, graph} ->
      socket =
        socket
        |> assign(:graph, graph)
        |> assign(:current_graph_name, name)
        |> assign(:history, ExFlow.HistoryManager.new())
        |> assign(:selected_node_ids, MapSet.new())
        |> assign(:selected_edge_ids, MapSet.new())
        |> put_flash(:info, "Graph '#{name}' loaded")

      {:noreply, socket}

    {:error, :not_found} ->
      {:noreply, put_flash(socket, :error, "Graph '#{name}' not found")}

    {:error, reason} ->
      {:noreply, put_flash(socket, :error, "Failed to load: #{inspect(reason)}")}
  end
end
```

### clear_graph

Clear all nodes and edges.

**Example:**

```elixir
@impl true
def handle_event("clear_graph", _params, socket) do
  socket =
    socket
    |> assign(:graph, ExFlow.Core.Graph.new())
    |> assign(:history, ExFlow.HistoryManager.new())
    |> assign(:selected_node_ids, MapSet.new())
    |> assign(:selected_edge_ids, MapSet.new())

  {:noreply, socket}
end
```

## Modal Events

Events for handling modals and forms.

### save_edit

Save changes from edit modal (for labels and metadata).

**Example:**

```elixir
@impl true
def handle_event("save_edit", params, socket) do
  label = params["label"] || ""
  metadata_input = params["metadata"] || "{}"

  label = if label == "", do: nil, else: label

  metadata = case Jason.decode(metadata_input) do
    {:ok, meta} -> meta
    {:error, _} -> socket.assigns.editing_item.metadata
  end

  case socket.assigns.editing_type do
    :node ->
      node = socket.assigns.editing_item

      case ExFlow.Core.Graph.update_node(socket.assigns.graph, node.id, %{
        label: label,
        metadata: metadata
      }) do
        {:ok, graph} ->
          {:noreply, assign(socket, graph: graph, show_edit_modal: false)}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to update node")}
      end

    :edge ->
      edge = socket.assigns.editing_item

      case ExFlow.Core.Graph.update_edge(socket.assigns.graph, edge.id, %{
        label: label,
        metadata: metadata
      }) do
        {:ok, graph} ->
          {:noreply, assign(socket, graph: graph, show_edit_modal: false)}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to update edge")}
      end
  end
end
```

### cancel_edit

Close edit modal without saving.

**Example:**

```elixir
@impl true
def handle_event("cancel_edit", _params, socket) do
  socket =
    socket
    |> assign(:show_edit_modal, false)
    |> assign(:editing_type, nil)
    |> assign(:editing_item, nil)

  {:noreply, socket}
end
```

## Complete Example LiveView

Here's a complete LiveView with all common event handlers:

```elixir
defmodule MyAppWeb.FlowLive do
  use MyAppWeb, :live_view

  alias ExFlow.Core.Graph, as: FlowGraph
  alias ExFlow.Storage.InMemory
  alias ExFlow.HistoryManager
  alias ExFlow.Commands.{CreateNodeCommand, CreateEdgeCommand, DeleteNodeCommand, DeleteEdgeCommand, MoveNodeCommand}

  @storage_id "my_workflow"

  @impl true
  def mount(_params, _session, socket) do
    graph = load_or_create_graph()
    history = HistoryManager.new()

    socket =
      socket
      |> assign(:graph, graph)
      |> assign(:history, history)
      |> assign(:selected_node_ids, MapSet.new())
      |> assign(:selected_edge_ids, MapSet.new())
      |> assign(:show_edit_modal, false)
      |> assign(:editing_type, nil)
      |> assign(:editing_item, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    nodes = nodes_for_ui(assigns.graph)
    edges = edges_for_ui(assigns.graph, nodes)
    assigns = assign(assigns, nodes: nodes, edges: edges)

    ~H"""
    <div class="container mx-auto p-4" phx-window-keydown="key_down">
      <div class="mb-4 flex gap-2">
        <button phx-click="add_node" phx-value-type="task" class="btn btn-sm">Add Task</button>
        <button phx-click="add_node" phx-value-type="agent" class="btn btn-sm">Add Agent</button>
        <button phx-click="undo" disabled={!HistoryManager.can_undo?(@history)} class="btn btn-sm">Undo</button>
        <button phx-click="redo" disabled={!HistoryManager.can_redo?(@history)} class="btn btn-sm">Redo</button>
        <button phx-click="delete_selected" class="btn btn-sm">Delete Selected</button>
      </div>

      <ExFlowGraphWeb.ExFlow.Canvas.canvas
        id="flow-canvas"
        style="height: 70vh;"
        nodes={@nodes}
        edges={@edges}
        selected_node_ids={@selected_node_ids}
        selected_edge_ids={@selected_edge_ids}
      />
    </div>
    """
  end

  # Canvas Events
  @impl true
  def handle_event("update_position", %{"id" => id, "x" => x, "y" => y}, socket) do
    command = MoveNodeCommand.new(id, %{x: x, y: y})
    execute_command(socket, command)
  end

  @impl true
  def handle_event("create_edge", params, socket) do
    %{
      "source_id" => source_id,
      "source_handle" => source_handle,
      "target_id" => target_id,
      "target_handle" => target_handle
    } = params

    edge_id = "edge-#{System.unique_integer([:positive])}"
    command = CreateEdgeCommand.new(edge_id, source_id, source_handle, target_id, target_handle)
    execute_command(socket, command)
  end

  @impl true
  def handle_event("select_node", %{"id" => id, "multi" => multi}, socket) do
    selected = handle_selection(socket.assigns.selected_node_ids, id, multi)
    {:noreply, assign(socket, selected_node_ids: selected, selected_edge_ids: MapSet.new())}
  end

  @impl true
  def handle_event("select_edge", %{"id" => id, "multi" => multi}, socket) do
    selected = handle_selection(socket.assigns.selected_edge_ids, id, multi)
    {:noreply, assign(socket, selected_edge_ids: selected, selected_node_ids: MapSet.new())}
  end

  @impl true
  def handle_event("option_click_node", %{"id" => id}, socket) do
    node = FlowGraph.get_nodes(socket.assigns.graph) |> Enum.find(&(&1.id == id))
    if node, do: open_edit_modal(socket, :node, node), else: {:noreply, socket}
  end

  @impl true
  def handle_event("option_click_edge", %{"id" => id}, socket) do
    edge = FlowGraph.get_edges(socket.assigns.graph) |> Enum.find(&(&1.id == id))
    if edge, do: open_edit_modal(socket, :edge, edge), else: {:noreply, socket}
  end

  # Keyboard Events
  @impl true
  def handle_event("key_down", %{"key" => "z", "meta" => true, "shift" => true}, socket) do
    handle_event("redo", %{}, socket)
  end

  def handle_event("key_down", %{"key" => "z", "meta" => true}, socket) do
    handle_event("undo", %{}, socket)
  end

  def handle_event("key_down", %{"key" => key}, socket) when key in ["Delete", "Backspace"] do
    handle_event("delete_selected", %{}, socket)
  end

  def handle_event("key_down", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, selected_node_ids: MapSet.new(), selected_edge_ids: MapSet.new())}
  end

  def handle_event("key_down", _params, socket), do: {:noreply, socket}

  # User Actions
  @impl true
  def handle_event("add_node", %{"type" => type_string}, socket) do
    type = String.to_existing_atom(type_string)
    node_id = "node-#{System.unique_integer([:positive])}"
    position = %{x: 100 + :rand.uniform(200), y: 100 + :rand.uniform(200)}

    command = CreateNodeCommand.new(node_id, type, %{
      position: position,
      label: "New #{type}",
      metadata: %{}
    })

    execute_command(socket, command)
  end

  @impl true
  def handle_event("undo", _params, socket) do
    case HistoryManager.undo(socket.assigns.history, socket.assigns.graph) do
      {:ok, history, graph} -> {:noreply, assign(socket, history: history, graph: graph)}
      {:error, _} -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("redo", _params, socket) do
    case HistoryManager.redo(socket.assigns.history, socket.assigns.graph) do
      {:ok, history, graph} -> {:noreply, assign(socket, history: history, graph: graph)}
      {:error, _} -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_selected", _params, socket) do
    node_commands = Enum.map(socket.assigns.selected_node_ids, &DeleteNodeCommand.new/1)
    edge_commands = Enum.map(socket.assigns.selected_edge_ids, &DeleteEdgeCommand.new/1)

    Enum.reduce(node_commands ++ edge_commands, {:noreply, socket}, fn cmd, {:noreply, acc_socket} ->
      case execute_command(acc_socket, cmd) do
        {:noreply, new_socket} -> {:noreply, new_socket}
        other -> other
      end
    end)
    |> then(fn {:noreply, final_socket} ->
      {:noreply, assign(final_socket, selected_node_ids: MapSet.new(), selected_edge_ids: MapSet.new())}
    end)
  end

  @impl true
  def handle_event("save_edit", params, socket) do
    # Implementation as shown in save_edit example above
    # ...
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, show_edit_modal: false)}
  end

  # Helper Functions
  defp execute_command(socket, command) do
    case HistoryManager.execute(socket.assigns.history, command, socket.assigns.graph) do
      {:ok, history, graph} ->
        :ok = InMemory.save(@storage_id, graph)
        {:noreply, assign(socket, history: history, graph: graph)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp handle_selection(current_set, id, "true") do
    if MapSet.member?(current_set, id) do
      MapSet.delete(current_set, id)
    else
      MapSet.put(current_set, id)
    end
  end

  defp handle_selection(_current_set, id, "false"), do: MapSet.new([id])

  defp open_edit_modal(socket, type, item) do
    metadata_json = Jason.encode!(item.metadata, pretty: true)

    socket =
      socket
      |> assign(:show_edit_modal, true)
      |> assign(:editing_type, type)
      |> assign(:editing_item, item)
      |> assign(:edit_label, item.label || "")
      |> assign(:edit_metadata, metadata_json)

    {:noreply, socket}
  end

  defp load_or_create_graph do
    case InMemory.load(@storage_id) do
      {:ok, graph} -> graph
      {:error, _} -> FlowGraph.new()
    end
  end

  defp nodes_for_ui(graph) do
    for node <- FlowGraph.get_nodes(graph) do
      %{
        id: node.id,
        title: node.label || node.id,
        x: node.position.x,
        y: node.position.y
      }
    end
  end

  defp edges_for_ui(graph, nodes) do
    node_by_id = Map.new(nodes, fn n -> {n.id, n} end)

    graph
    |> FlowGraph.get_edges()
    |> Enum.map(fn edge ->
      source = Map.get(node_by_id, edge.source)
      target = Map.get(node_by_id, edge.target)

      if source && target do
        %{
          id: edge.id,
          source_id: edge.source,
          target_id: edge.target,
          source_x: source.x + 12,
          source_y: source.y + 12,
          target_x: target.x + 12,
          target_y: target.y + 12
        }
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
```

## Event Summary Table

| Event | Trigger | Parameters | Common Use |
|-------|---------|------------|------------|
| `update_position` | Node dragged | id, x, y | Update node position |
| `create_edge` | Handle drag completed | source_id, source_handle, target_id, target_handle | Create new edge |
| `select_node` | Node clicked | id, multi | Select/deselect node |
| `select_edge` | Edge clicked | id, multi | Select/deselect edge |
| `option_click_node` | Option+Click node | id | Edit node, show details |
| `option_click_edge` | Option+Click edge | id | Edit edge, show details |
| `key_down` | Keyboard press | key, meta, shift, alt | Shortcuts (undo/redo/delete) |
| `add_node` | Button click | type | Create new node |
| `delete_selected` | Button/key press | - | Delete selections |
| `undo` | Button/key press | - | Undo last action |
| `redo` | Button/key press | - | Redo last undone action |
| `save_edit` | Form submit | label, metadata | Save modal changes |
| `cancel_edit` | Button click | - | Close modal |

## Best Practices

1. **Always use commands with history** - Execute operations through `HistoryManager.execute/3` to enable undo/redo
2. **Clear selections on actions** - Reset selection after delete operations
3. **Provide visual feedback** - Use flash messages for save/load operations
4. **Validate inputs** - Check for valid JSON in metadata fields
5. **Handle errors gracefully** - Always pattern match on `{:ok, _}` and `{:error, _}`
6. **Save after changes** - Persist graph to storage after successful operations
7. **Use keyboard shortcuts** - Implement common shortcuts (Cmd+Z, Delete, Escape)
8. **Batch operations** - Group multiple commands for complex operations
