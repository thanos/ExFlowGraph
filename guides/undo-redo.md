# Undo/Redo with History Management

ExFlowGraph includes a complete undo/redo system built on the Command Pattern. This allows users to undo and redo their graph modifications with full history tracking.

## Overview

The undo/redo system consists of three main components:

1. **Command Protocol** (`ExFlow.Command`) - Defines the interface for undoable operations
2. **History Manager** (`ExFlow.HistoryManager`) - Manages the undo/redo stacks
3. **Built-in Commands** - Pre-built commands for common operations

## Quick Start

### Basic Setup

In your LiveView's `mount/3`, initialize the history manager:

```elixir
def mount(_params, _session, socket) do
  graph = ExFlow.Core.Graph.new()
  history = ExFlow.HistoryManager.new()  # Optional: new(max_size)

  socket =
    socket
    |> assign(:graph, graph)
    |> assign(:history, history)

  {:ok, socket}
end
```

### Executing Commands

Use `HistoryManager.execute/3` instead of calling Graph functions directly:

```elixir
def handle_event("add_node", _params, socket) do
  # Create command
  command = ExFlow.Commands.CreateNodeCommand.new(
    "node-#{System.unique_integer([:positive])}",
    :task,
    %{position: %{x: 100, y: 100}, label: "New Task"}
  )

  # Execute with history tracking
  case ExFlow.HistoryManager.execute(socket.assigns.history, command, socket.assigns.graph) do
    {:ok, history, graph} ->
      {:noreply, assign(socket, history: history, graph: graph)}

    {:error, reason} ->
      {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
  end
end
```

### Undo and Redo

Implement undo/redo event handlers:

```elixir
def handle_event("undo", _params, socket) do
  case ExFlow.HistoryManager.undo(socket.assigns.history, socket.assigns.graph) do
    {:ok, history, graph} ->
      {:noreply, assign(socket, history: history, graph: graph)}

    {:error, :nothing_to_undo} ->
      {:noreply, socket}
  end
end

def handle_event("redo", _params, socket) do
  case ExFlow.HistoryManager.redo(socket.assigns.history, socket.assigns.graph) do
    {:ok, history, graph} ->
      {:noreply, assign(socket, history: history, graph: graph)}

    {:error, :nothing_to_redo} ->
      {:noreply, socket}
  end
end
```

### UI Buttons

Add undo/redo buttons to your template:

```heex
<button
  phx-click="undo"
  disabled={!ExFlow.HistoryManager.can_undo?(@history)}
  class="btn btn-sm"
>
  ↶ Undo
</button>

<button
  phx-click="redo"
  disabled={!ExFlow.HistoryManager.can_redo?(@history)}
  class="btn btn-sm"
>
  ↷ Redo
</button>
```

## Built-in Commands

ExFlowGraph provides commands for all core operations:

### CreateNodeCommand

```elixir
command = ExFlow.Commands.CreateNodeCommand.new(
  "node-id",
  :agent,
  %{
    position: %{x: 100, y: 100},
    label: "Agent Node",
    metadata: %{status: "active"}
  }
)
```

### DeleteNodeCommand

```elixir
command = ExFlow.Commands.DeleteNodeCommand.new("node-id")
```

### MoveNodeCommand

```elixir
command = ExFlow.Commands.MoveNodeCommand.new(
  "node-id",
  %{x: 200, y: 150}  # new position
)
```

### CreateEdgeCommand

```elixir
command = ExFlow.Commands.CreateEdgeCommand.new(
  "edge-id",
  "source-node-id",
  "out",
  "target-node-id",
  "in",
  %{
    label: "data flow",
    metadata: %{protocol: "http"}
  }
)
```

### DeleteEdgeCommand

```elixir
command = ExFlow.Commands.DeleteEdgeCommand.new("edge-id")
```

## History Manager API

### Core Functions

```elixir
# Create new history manager (default max 50 commands)
history = ExFlow.HistoryManager.new()
history = ExFlow.HistoryManager.new(100)  # Custom max size

# Execute command
{:ok, history, graph} = ExFlow.HistoryManager.execute(history, command, graph)

# Undo last command
{:ok, history, graph} = ExFlow.HistoryManager.undo(history, graph)

# Redo last undone command
{:ok, history, graph} = ExFlow.HistoryManager.redo(history, graph)
```

### Query Functions

```elixir
# Check if undo/redo is available
can_undo? = ExFlow.HistoryManager.can_undo?(history)
can_redo? = ExFlow.HistoryManager.can_redo?(history)

# Get descriptions
description = ExFlow.HistoryManager.next_undo_description(history)
description = ExFlow.HistoryManager.next_redo_description(history)

# Get counts
past_count = ExFlow.HistoryManager.past_count(history)
future_count = ExFlow.HistoryManager.future_count(history)

# Clear all history
history = ExFlow.HistoryManager.clear(history)
```

## Keyboard Shortcuts

Add keyboard shortcuts for a better UX:

```elixir
def handle_event("key_down", %{"key" => "z", "meta" => true, "shift" => true}, socket) do
  # Cmd+Shift+Z or Ctrl+Shift+Z - Redo
  handle_event("redo", %{}, socket)
end

def handle_event("key_down", %{"key" => "z", "meta" => true}, socket) do
  # Cmd+Z or Ctrl+Z - Undo
  handle_event("undo", %{}, socket)
end

def handle_event("key_down", %{"key" => "y", "meta" => true}, socket) do
  # Cmd+Y or Ctrl+Y - Redo (alternative)
  handle_event("redo", %{}, socket)
end

def handle_event("key_down", _params, socket) do
  {:noreply, socket}
end
```

Add event listener to your template:

```heex
<div phx-window-keydown="key_down">
  <!-- Your content -->
</div>
```

## Creating Custom Commands

Implement the `ExFlow.Command` behaviour to create custom commands:

```elixir
defmodule MyApp.Commands.UpdateNodeColorCommand do
  @behaviour ExFlow.Command

  alias ExFlow.Core.Graph

  defstruct [:node_id, :new_color, :old_color]

  def new(node_id, new_color) do
    %__MODULE__{
      node_id: node_id,
      new_color: new_color,
      old_color: nil  # Will be set during execute
    }
  end

  @impl ExFlow.Command
  def execute(%__MODULE__{} = cmd, graph) do
    nodes = Graph.get_nodes(graph)
    node = Enum.find(nodes, &(&1.id == cmd.node_id))

    if node do
      # Store old color for undo
      old_color = node.metadata[:color]
      new_metadata = Map.put(node.metadata, :color, cmd.new_color)

      case Graph.update_node(graph, cmd.node_id, %{metadata: new_metadata}) do
        {:ok, graph} ->
          # Update command with old color
          cmd = %{cmd | old_color: old_color}
          {:ok, graph}

        error ->
          error
      end
    else
      {:error, :node_not_found}
    end
  end

  @impl ExFlow.Command
  def undo(%__MODULE__{} = cmd, graph) do
    nodes = Graph.get_nodes(graph)
    node = Enum.find(nodes, &(&1.id == cmd.node_id))

    if node do
      new_metadata = Map.put(node.metadata, :color, cmd.old_color)
      Graph.update_node(graph, cmd.node_id, %{metadata: new_metadata})
    else
      {:error, :node_not_found}
    end
  end

  @impl ExFlow.Command
  def description(%__MODULE__{} = cmd) do
    "Change node '#{cmd.node_id}' color to #{cmd.new_color}"
  end
end
```

## Advanced Patterns

### Batch Commands

For complex operations that should undo as a single unit:

```elixir
defmodule MyApp.Commands.BatchCommand do
  @behaviour ExFlow.Command

  defstruct [:commands, :description_text]

  def new(commands, description) do
    %__MODULE__{commands: commands, description_text: description}
  end

  @impl ExFlow.Command
  def execute(%__MODULE__{commands: commands}, graph) do
    Enum.reduce_while(commands, {:ok, graph}, fn cmd, {:ok, acc_graph} ->
      case ExFlow.Command.execute(cmd, acc_graph) do
        {:ok, new_graph} -> {:cont, {:ok, new_graph}}
        error -> {:halt, error}
      end
    end)
  end

  @impl ExFlow.Command
  def undo(%__MODULE__{commands: commands}, graph) do
    # Undo in reverse order
    commands
    |> Enum.reverse()
    |> Enum.reduce_while({:ok, graph}, fn cmd, {:ok, acc_graph} ->
      case ExFlow.Command.undo(cmd, acc_graph) do
        {:ok, new_graph} -> {:cont, {:ok, new_graph}}
        error -> {:halt, error}
      end
    end)
  end

  @impl ExFlow.Command
  def description(%__MODULE__{description_text: desc}), do: desc
end
```

### Conditional Commands

Only execute if certain conditions are met:

```elixir
def handle_event("delete_selected", _params, socket) do
  if MapSet.size(socket.assigns.selected_node_ids) > 0 do
    commands =
      socket.assigns.selected_node_ids
      |> Enum.map(&ExFlow.Commands.DeleteNodeCommand.new/1)

    batch_command = MyApp.Commands.BatchCommand.new(
      commands,
      "Delete #{MapSet.size(socket.assigns.selected_node_ids)} nodes"
    )

    case ExFlow.HistoryManager.execute(socket.assigns.history, batch_command, socket.assigns.graph) do
      {:ok, history, graph} ->
        socket =
          socket
          |> assign(history: history, graph: graph)
          |> assign(selected_node_ids: MapSet.new())

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  else
    {:noreply, socket}
  end
end
```

## Best Practices

1. **Always use commands for graph modifications** - Don't call Graph functions directly if you want undo support
2. **Store necessary data for undo** - Commands should capture enough information to reverse themselves
3. **Keep commands simple** - Each command should do one thing
4. **Use batch commands for multi-step operations** - Ensures atomic undo/redo
5. **Set appropriate history limits** - Balance memory usage with user needs (default is 50)
6. **Provide clear descriptions** - Help users understand what will be undone/redone
7. **Handle errors gracefully** - Commands can fail, handle `{:error, reason}` responses

## Demo Application

The demo application (`/demo`) includes a complete undo/redo implementation with:

- Keyboard shortcuts (Cmd/Ctrl+Z, Cmd/Ctrl+Shift+Z)
- UI buttons with enabled/disabled states
- History count display
- All operations use commands (create, delete, move nodes/edges)

Reference the demo code for a production-ready example:

```bash
cd demo
mix phx.server
# Visit http://localhost:4000
# Try creating/deleting nodes and using Cmd+Z / Cmd+Shift+Z
```

## Architecture

The undo/redo system uses two stacks:

```
Past Stack (executed commands)
[CreateNode, MoveNode, CreateEdge]
              ↑
           Current State
              ↓
Future Stack (undone commands)
[DeleteNode]
```

- **Execute**: Command is executed, added to past stack, future stack is cleared
- **Undo**: Top command from past moves to future, command is reversed
- **Redo**: Top command from future moves to past, command is executed again

This ensures:
- Any new action clears the future (can't redo after modifying)
- Full history of actions
- Efficient memory usage with configurable limits
