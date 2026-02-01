# Option/Alt + Click Events

ExFlowGraph now supports Option/Alt + Click events on both nodes and edges, allowing you to trigger custom actions without interfering with normal drag, select, or pan operations.

## Feature Overview

- **Option/Alt + Click Node**: Triggers `option_click_node` event with node ID
- **Option/Alt + Click Edge**: Triggers `option_click_edge` event with edge ID
- Works independently of other modifiers (Shift, Ctrl, Cmd for multi-select)
- Edges have enhanced click detection with invisible 20px wide hit area

## Usage

### Handling Node Click Events

In your LiveView, implement the `handle_event/3` callback:

```elixir
@impl true
def handle_event("option_click_node", %{"id" => id}, socket) do
  # Get the node data
  node = ExFlow.Core.Graph.get_nodes(socket.assigns.graph)
         |> Enum.find(&(&1.id == id))

  # Your custom logic here:
  # - Show a modal with node details
  # - Open an edit form
  # - Display metadata in a panel
  # - Log information
  # - Delete the node
  # - Anything else!

  {:noreply, socket}
end
```

### Handling Edge Click Events

```elixir
@impl true
def handle_event("option_click_edge", %{"id" => id}, socket) do
  # Get the edge data
  edge = ExFlow.Core.Graph.get_edges(socket.assigns.graph)
         |> Enum.find(&(&1.id == id))

  # Your custom logic here:
  # - Show edge properties
  # - Edit edge label or metadata
  # - Delete the edge
  # - Change edge styling
  # - Anything else!

  {:noreply, socket}
end
```

## Demo Implementation

The demo app logs node and edge details to the console when Option/Alt + clicked:

### Node Click Output
```
=== Option+Click Node ===
ID: agent-1
Type: agent
Label: "Data Processor"
Position: %{x: 120, y: 120}
Metadata: %{status: "active", priority: "high"}
========================
```

### Edge Click Output
```
=== Option+Click Edge ===
ID: edge-1
Source: agent-1 (out)
Target: task-1 (in)
Label: "data flow"
Metadata: %{bandwidth: "high", protocol: "streaming"}
========================
```

## Common Use Cases

### 1. Show Details Modal

```elixir
def handle_event("option_click_node", %{"id" => id}, socket) do
  node = get_node(socket.assigns.graph, id)

  socket =
    socket
    |> assign(:show_node_details, true)
    |> assign(:selected_node_for_details, node)

  {:noreply, socket}
end
```

### 2. Quick Delete

```elixir
def handle_event("option_click_node", %{"id" => id}, socket) do
  command = ExFlow.Commands.DeleteNodeCommand.new(id)

  case ExFlow.HistoryManager.execute(socket.assigns.history, command, socket.assigns.graph) do
    {:ok, history, graph} ->
      {:noreply, assign(socket, graph: graph, history: history)}
    {:error, _} ->
      {:noreply, socket}
  end
end
```

### 3. Edit Properties

```elixir
def handle_event("option_click_edge", %{"id" => id}, socket) do
  edge = get_edge(socket.assigns.graph, id)

  socket =
    socket
    |> assign(:editing_edge, edge)
    |> assign(:show_edge_editor, true)

  {:noreply, socket}
end
```

### 4. Toggle State

```elixir
def handle_event("option_click_node", %{"id" => id}, socket) do
  # Toggle a node's state in metadata
  graph = socket.assigns.graph
  node = get_node(graph, id)

  new_state = if node.metadata[:enabled], do: false, else: true
  updated_metadata = Map.put(node.metadata, :enabled, new_state)

  # Update node with new metadata
  # (You'd need to implement an update_node function)

  {:noreply, socket}
end
```

## Keyboard Shortcuts Summary

| Action | Shortcut | Description |
|--------|----------|-------------|
| Select Node | Click | Select single node |
| Multi-select | Shift/Ctrl/Cmd + Click | Add/remove from selection |
| Drag Node | Click + Drag | Move node |
| Create Edge | Click handle + Drag | Create new edge |
| Pan Canvas | Click canvas + Drag | Pan the view |
| **Custom Action** | **Option/Alt + Click** | **Trigger custom event** |

## Edge Click Detection

Edges now have a 20px invisible stroke area for easier clicking:
- Visible path: 2px stroke
- Hit area: 20px transparent stroke
- Hover effect: Color changes on hover
- Cursor: Changes to pointer on hover

## Technical Details

### JavaScript Hook

The hook detects `e.altKey` on mousedown:

```javascript
// For nodes
if (e.altKey) {
  this.pushEvent("option_click_node", { id })
  return
}

// For edges
if (edgeEl && e.altKey) {
  this.pushEvent("option_click_edge", { id: edgeId })
  return
}
```

### Edge Component Structure

```heex
<g>
  <!-- Invisible wider path for clicking -->
  <path
    class="exflow-edge"
    stroke="transparent"
    stroke-width="20"
    style="cursor: pointer;"
  />
  <!-- Visible path -->
  <path
    stroke-width="2"
    style="pointer-events: none;"
  />
</g>
```

## Notes

- Option/Alt key works on both Mac (Option) and Windows/Linux (Alt)
- The event fires immediately on mousedown, preventing normal drag behavior
- Use this for non-destructive actions or show confirmations for destructive ones
- The feature is completely optional - if you don't handle the events, nothing happens
- Events include the element ID for easy data lookup

## Try It Now!

1. Start the demo: `mix phx.server`
2. Visit http://localhost:4000
3. Hold Option/Alt and click on a node
4. Hold Option/Alt and click on an edge
5. Check your terminal console for the logged details!

The console output shows all the node/edge data including labels and metadata, demonstrating how you can access and use this information in your custom handlers.
