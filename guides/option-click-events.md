# Option/Alt + Click Events

ExFlowGraph supports Option/Alt + Click events on both nodes and edges, allowing you to trigger custom actions without interfering with normal drag, select, or pan operations.

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

### 2. Edit Properties with Modal

The demo application implements a full edit modal that opens on Option+Click:

```elixir
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

Then implement the save handler:

```elixir
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
        {:error, _} ->
          {:noreply, socket}
      end

    :edge ->
      edge = socket.assigns.editing_item
      case ExFlow.Core.Graph.update_edge(socket.assigns.graph, edge.id, %{
        label: label,
        metadata: metadata
      }) do
        {:ok, graph} ->
          {:noreply, assign(socket, graph: graph, show_edit_modal: false)}
        {:error, _} ->
          {:noreply, socket}
      end
  end
end
```

### 3. Quick Delete

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

### 4. Toggle State

```elixir
def handle_event("option_click_node", %{"id" => id}, socket) do
  # Toggle a node's state in metadata
  graph = socket.assigns.graph
  nodes = ExFlow.Core.Graph.get_nodes(graph)
  node = Enum.find(nodes, &(&1.id == id))

  if node do
    new_state = if node.metadata[:enabled], do: false, else: true
    updated_metadata = Map.put(node.metadata, :enabled, new_state)

    case ExFlow.Core.Graph.update_node(graph, id, %{metadata: updated_metadata}) do
      {:ok, graph} ->
        {:noreply, assign(socket, graph: graph)}
      {:error, _} ->
        {:noreply, socket}
    end
  else
    {:noreply, socket}
  end
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

Edges have enhanced click detection with a two-layer structure:

- **Visible path**: 2px stroke (4px when selected)
- **Hit area**: 20px transparent stroke for easier clicking
- **Hover effect**: Color changes on hover
- **Cursor**: Changes to pointer on hover

## Technical Details

### JavaScript Hook

The ExFlowCanvas hook detects `e.altKey` on mousedown:

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

The Edge component uses a two-layer SVG structure:

```heex
<g>
  <!-- Invisible wider path for clicking -->
  <path
    class="exflow-edge"
    fill="none"
    stroke="transparent"
    stroke-width="20"
    data-edge-id={@id}
    style="cursor: pointer;"
  />

  <!-- Visible path -->
  <path
    id={"exflow-edge-#{@id}"}
    fill="none"
    stroke-width={if(@selected, do: "4", else: "2")}
    style="pointer-events: none;"
    class={[
      "transition-colors",
      if(@selected,
         do: "stroke-primary stroke-4",
         else: "stroke-base-content/50 hover:stroke-base-content/80 stroke-2")
    ]}
  />
</g>
```

## Notes

- Option/Alt key works on both Mac (Option) and Windows/Linux (Alt)
- The event fires immediately on mousedown, preventing normal drag behavior
- Use this for non-destructive actions or show confirmations for destructive ones
- The feature is completely optional - if you don't handle the events, nothing happens
- Events include the element ID for easy data lookup
- The demo app provides a complete implementation with edit modals

## Demo Application

The demo application shows a complete implementation with:

1. Option+Click on nodes opens an edit modal
2. Option+Click on edges opens an edit modal
3. Modal has form inputs for label and metadata (JSON)
4. Save button updates the graph
5. Cancel button closes modal without changes

Run the demo to see it in action:

```bash
cd demo
mix phx.server
# Visit http://localhost:4000
# Hold Option/Alt and click on nodes or edges
```
