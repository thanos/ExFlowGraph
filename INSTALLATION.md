# ExFlowGraph Installation & Setup Guide

Complete guide to installing and using ExFlowGraph in your Phoenix LiveView application.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Basic Setup](#basic-setup)
5. [Usage Examples](#usage-examples)
6. [Advanced Features](#advanced-features)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- **Elixir**: >= 1.15
- **Phoenix**: >= 1.8
- **Phoenix LiveView**: >= 1.0
- **Tailwind CSS**: v4.x (for styling)
- **DaisyUI**: (optional, for enhanced UI)

---

## Installation

### Step 1: Add Dependency

Add ExFlowGraph to your `mix.exs` dependencies:

```elixir
# mix.exs
defp deps do
  [
    {:ex_flow_graph, path: "../ExFlowGraph"},  # For local development
    # OR for production (when published to Hex):
    # {:ex_flow_graph, "~> 0.1.0"},

    # Required dependencies (if not already present)
    {:phoenix_live_view, "~> 1.0"},
    {:libgraph, "~> 0.16"},
    {:jason, "~> 1.2"}
  ]
end
```

### Step 2: Install Dependencies

```bash
mix deps.get
mix compile
```

---

## Configuration

### Step 1: Import Components

In your `lib/your_app_web.ex` file, import the ExFlowGraph components:

```elixir
# lib/your_app_web.ex
defmodule YourAppWeb do
  # ... existing code ...

  defp html_helpers do
    quote do
      use Gettext, backend: YourAppWeb.Gettext
      import Phoenix.HTML
      import YourAppWeb.CoreComponents

      # Import ExFlowGraph components
      import ExFlowGraphWeb.ExFlow.Canvas
      import ExFlowGraphWeb.ExFlow.Node
      import ExFlowGraphWeb.ExFlow.Edge

      alias Phoenix.LiveView.JS
      unquote(verified_routes())
    end
  end
end
```

### Step 2: Configure JavaScript Hook

Add the ExFlowCanvas hook to your `assets/js/app.js`:

```javascript
// assets/js/app.js
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Import ExFlowCanvas hook
import ExFlowCanvas from "../../deps/ex_flow_graph/assets/js/hooks/ex_flow"
// OR for local path dependency:
// import ExFlowCanvas from "../../../ExFlowGraph/assets/js/hooks/ex_flow"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {ExFlowCanvas}  // Register the hook
})

// ... rest of your app.js
```

### Step 3: Configure Tailwind CSS

Update your `assets/css/app.css` to include ExFlowGraph styles:

```css
/* assets/css/app.css */
@import "tailwindcss";
@source "../css";
@source "../js";
@source "../../lib/your_app_web";

/* Add ExFlowGraph component source */
@source "../../deps/ex_flow_graph/lib/ex_flow_graph_web";
/* OR for local path dependency: */
/* @source "../../../ExFlowGraph/lib/ex_flow_graph_web"; */

/* ... rest of your CSS config ... */
```

**Important for Tailwind v4**: Create a safelist file to ensure all component classes are generated:

```elixir
# lib/your_app_web/components/exflow_safelist.ex
defmodule YourAppWeb.Components.ExFlowSafelist do
  use Phoenix.Component

  def safelist(assigns) do
    ~H"""
    <div class="hidden">
      <!-- Canvas classes -->
      <div class="relative w-full overflow-hidden rounded-2xl border border-base-300 bg-gradient-to-br from-base-200/40 to-base-100"></div>
      <div class="exflow-container absolute inset-0"></div>

      <!-- Node classes -->
      <div class="exflow-node absolute select-none rounded-lg border bg-base-100/90 shadow-sm backdrop-blur px-3 py-2 text-sm text-base-content cursor-grab active:cursor-grabbing pointer-events-auto transition-all border-primary border-2 ring-2 ring-primary/30 shadow-lg border-base-300 font-medium mt-2 flex gap-2"></div>
      <span class="exflow-handle exflow-handle-source inline-flex size-2 rounded-full bg-primary cursor-crosshair hover:scale-150 transition-transform"></span>
      <span class="exflow-handle exflow-handle-target inline-flex size-2 rounded-full bg-base-content/40 cursor-crosshair hover:scale-150 transition-transform"></span>

      <!-- Edge classes -->
      <svg><path class="exflow-edge stroke-base-content/50 hover:stroke-base-content/80 transition-colors stroke-primary stroke-2 stroke-4"></path></svg>
    </div>
    """
  end
end
```

### Step 4: Rebuild Assets

```bash
mix assets.deploy
```

---

## Basic Setup

### Step 1: Create a LiveView Module

```elixir
# lib/your_app_web/live/flow_live.ex
defmodule YourAppWeb.FlowLive do
  use YourAppWeb, :live_view

  alias ExFlow.Core.Graph, as: FlowGraph
  alias ExFlow.Storage.InMemory

  @storage_id "my_workflow"

  @impl true
  def mount(_params, _session, socket) do
    # Load existing graph or create new one
    graph = case InMemory.load(@storage_id) do
      {:ok, graph} -> graph
      {:error, _} -> create_initial_graph()
    end

    socket =
      socket
      |> assign(:graph, graph)
      |> assign(:selected_node_ids, MapSet.new())
      |> assign(:selected_edge_ids, MapSet.new())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    nodes = nodes_for_ui(assigns.graph)
    edges = edges_for_ui(assigns.graph, nodes)

    assigns = assign(assigns, nodes: nodes, edges: edges)

    ~H"""
    <div class="container mx-auto p-4">
      <h1 class="text-2xl font-bold mb-4">My Workflow</h1>

      <div class="rounded-2xl border border-base-300 bg-base-100 shadow-lg overflow-hidden">
        <ExFlowGraphWeb.ExFlow.Canvas.canvas
          id="flow-canvas"
          nodes={@nodes}
          edges={@edges}
          selected_node_ids={@selected_node_ids}
          selected_edge_ids={@selected_edge_ids}
        />
      </div>
    </div>
    """
  end

  # Event handlers
  @impl true
  def handle_event("update_position", %{"id" => id, "x" => x, "y" => y}, socket) do
    case FlowGraph.update_node_position(socket.assigns.graph, id, %{x: x, y: y}) do
      {:ok, graph} ->
        :ok = InMemory.save(@storage_id, graph)
        {:noreply, assign(socket, :graph, graph)}
      {:error, _} ->
        {:noreply, socket}
    end
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

    case FlowGraph.add_edge(
      socket.assigns.graph,
      edge_id,
      source_id,
      source_handle,
      target_id,
      target_handle
    ) do
      {:ok, graph} ->
        :ok = InMemory.save(@storage_id, graph)
        {:noreply, assign(socket, :graph, graph)}
      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_node", %{"id" => id, "multi" => multi}, socket) do
    selected =
      if multi == "true" do
        if MapSet.member?(socket.assigns.selected_node_ids, id) do
          MapSet.delete(socket.assigns.selected_node_ids, id)
        else
          MapSet.put(socket.assigns.selected_node_ids, id)
        end
      else
        MapSet.new([id])
      end

    {:noreply, assign(socket, :selected_node_ids, selected)}
  end

  @impl true
  def handle_event("select_edge", %{"id" => id, "multi" => multi}, socket) do
    selected =
      if multi == "true" do
        if MapSet.member?(socket.assigns.selected_edge_ids, id) do
          MapSet.delete(socket.assigns.selected_edge_ids, id)
        else
          MapSet.put(socket.assigns.selected_edge_ids, id)
        end
      else
        MapSet.new([id])
      end

    {:noreply, assign(socket, :selected_edge_ids, selected)}
  end

  # Helper functions
  defp create_initial_graph do
    graph = FlowGraph.new()

    {:ok, graph} =
      FlowGraph.add_node(graph, "node-1", :task, %{
        position: %{x: 100, y: 100},
        label: "Start",
        metadata: %{}
      })

    {:ok, graph} =
      FlowGraph.add_node(graph, "node-2", :task, %{
        position: %{x: 400, y: 100},
        label: "Process",
        metadata: %{}
      })

    {:ok, graph} =
      FlowGraph.add_edge(graph, "edge-1", "node-1", "out", "node-2", "in")

    :ok = InMemory.save(@storage_id, graph)
    graph
  end

  defp nodes_for_ui(graph) do
    for node <- FlowGraph.get_nodes(graph) do
      %{
        id: node.id,
        title: node.label || node.id,
        label: node.label,
        metadata: node.metadata,
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
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
```

### Step 2: Add Route

```elixir
# lib/your_app_web/router.ex
scope "/", YourAppWeb do
  pipe_through :browser

  live "/flow", FlowLive
end
```

### Step 3: Run Your Application

```bash
mix phx.server
```

Visit `http://localhost:4000/flow` to see your graph!

---

## Usage Examples

### Creating Nodes

```elixir
# Add a node with label and metadata
{:ok, graph} = FlowGraph.add_node(graph, "my-node", :agent, %{
  position: %{x: 200, y: 150},
  label: "ML Processor",
  metadata: %{
    model: "gpt-4",
    temperature: 0.7
  }
})
```

### Creating Edges

```elixir
# Connect two nodes
{:ok, graph} = FlowGraph.add_edge(
  graph,
  "my-edge",
  "source-node-id",
  "out",
  "target-node-id",
  "in",
  %{
    label: "data flow",
    metadata: %{bandwidth: "high"}
  }
)
```

### Updating Nodes

```elixir
# Update node position
{:ok, graph} = FlowGraph.update_node_position(
  graph,
  "my-node",
  %{x: 250, y: 200}
)

# Update node label and metadata
{:ok, graph} = FlowGraph.update_node(
  graph,
  "my-node",
  %{
    label: "Updated Label",
    metadata: %{new_field: "value"}
  }
)
```

### Deleting Elements

```elixir
# Delete a node
{:ok, graph} = FlowGraph.delete_node(graph, "my-node")

# Delete an edge
{:ok, graph} = FlowGraph.delete_edge(graph, "my-edge")
```

---

## Advanced Features

### 1. Undo/Redo with History Manager

```elixir
alias ExFlow.HistoryManager
alias ExFlow.Commands.CreateNodeCommand

# Initialize history
history = HistoryManager.new()

# Execute command with history
command = CreateNodeCommand.new("node-1", :task, %{position: %{x: 100, y: 100}})
{:ok, history, graph} = HistoryManager.execute(history, command, graph)

# Undo
case HistoryManager.undo(history, graph) do
  {:ok, history, graph} ->
    # Node removed
  {:error, :nothing_to_undo} ->
    # At beginning of history
end

# Redo
case HistoryManager.redo(history, graph) do
  {:ok, history, graph} ->
    # Node restored
  {:error, :nothing_to_redo} ->
    # At end of history
end
```

### 2. Custom Option+Click Actions

Handle Option/Alt + Click events on nodes and edges:

```elixir
@impl true
def handle_event("option_click_node", %{"id" => id}, socket) do
  node = FlowGraph.get_nodes(socket.assigns.graph)
         |> Enum.find(&(&1.id == id))

  socket =
    socket
    |> assign(:show_details_modal, true)
    |> assign(:selected_node, node)

  {:noreply, socket}
end

@impl true
def handle_event("option_click_edge", %{"id" => id}, socket) do
  edge = FlowGraph.get_edges(socket.assigns.graph)
         |> Enum.find(&(&1.id == id))

  # Your custom logic here
  {:noreply, socket}
end
```

### 3. Keyboard Shortcuts

The JavaScript hook automatically handles:

- **Drag node**: Click and drag
- **Multi-select**: Shift/Ctrl/Cmd + Click
- **Create edge**: Drag from source handle to target handle
- **Pan canvas**: Drag on empty canvas
- **Custom action**: Option/Alt + Click

### 4. Persistent Storage

#### In-Memory Storage (Development)

```elixir
alias ExFlow.Storage.InMemory

# Save
:ok = InMemory.save("my-workflow", graph)

# Load
{:ok, graph} = InMemory.load("my-workflow")

# List all
graphs = InMemory.list()

# Delete
:ok = InMemory.delete("my-workflow")
```

#### Database Storage (Production)

For production, implement your own storage module:

```elixir
defmodule MyApp.FlowStorage do
  @behaviour ExFlow.Storage

  def save(id, graph) do
    # Serialize graph and save to database
    MyApp.Repo.insert_or_update(%Workflow{
      id: id,
      graph_data: :erlang.term_to_binary(graph)
    })
  end

  def load(id) do
    case MyApp.Repo.get(Workflow, id) do
      nil -> {:error, :not_found}
      workflow ->
        graph = :erlang.binary_to_term(workflow.graph_data)
        {:ok, graph}
    end
  end

  def delete(id) do
    MyApp.Repo.delete(%Workflow{id: id})
  end

  def list() do
    MyApp.Repo.all(Workflow)
    |> Enum.map(& &1.id)
  end
end
```

### 5. Custom Styling

Override default styles in your CSS:

```css
/* Make nodes larger */
.exflow-node {
  padding: 1rem;
  font-size: 1rem;
}

/* Custom edge colors */
.exflow-edge {
  stroke: #3b82f6 !important;
  stroke-width: 3;
}

/* Custom selection style */
.exflow-node.selected {
  border: 3px solid #10b981;
  box-shadow: 0 0 0 4px rgba(16, 185, 129, 0.2);
}
```

---

## Troubleshooting

### Issue: Graph Not Displaying

**Problem**: Canvas shows but nodes/edges are invisible.

**Solution**: Check if Tailwind is scanning library files:

1. Verify `@source` directive in `assets/css/app.css`
2. Add safelist file (see Configuration Step 3)
3. Rebuild assets: `mix assets.deploy`

### Issue: JavaScript Hook Not Working

**Problem**: Can't drag nodes or create edges.

**Solution**:

1. Verify hook import in `app.js`
2. Check hook registration: `hooks: {ExFlowCanvas}`
3. Ensure `phx-hook="ExFlowCanvas"` attribute on canvas div
4. Check browser console for JavaScript errors

### Issue: Edges Not Clickable

**Problem**: Can't select or Option+Click edges.

**Solution**:

1. Ensure SVG doesn't have `pointer-events-none` class
2. Edge component should have invisible hit area (20px stroke)
3. Check z-index layering (edges at z-0, nodes at z-10)

### Issue: Canvas Has Zero Height

**Problem**: Canvas is invisible or very small.

**Solution**:

Add inline style to canvas:
```heex
<ExFlowGraphWeb.ExFlow.Canvas.canvas
  style="height: 70vh;"
  ...
/>
```

### Issue: Module Not Found Errors

**Problem**: Can't find ExFlowGraph modules.

**Solution**:

1. Run `mix deps.get`
2. Run `mix compile`
3. Verify dependency in `mix.exs`
4. Check import statements in `your_app_web.ex`

---

## Demo Application Reference

The complete demo application at `/demo` provides:

- Full-featured workflow editor
- Undo/Redo functionality
- Save/Load graphs
- Node and edge editing modals
- Selection management
- Keyboard shortcuts
- Test graph generation

**Key Demo Files to Reference**:

1. **`demo/lib/demo_web/live/home_live.ex`** - Complete LiveView implementation
2. **`demo/assets/js/app.js`** - JavaScript hook setup
3. **`demo/assets/css/app.css`** - CSS configuration
4. **`demo/lib/demo_web.ex`** - Component imports

---

## Next Steps

1. ✅ Install ExFlowGraph in your project
2. ✅ Configure Tailwind and JavaScript
3. ✅ Create your first LiveView with a graph
4. 📚 Read `LABELS_AND_METADATA.md` for data handling
5. 📚 Read `OPTION_CLICK.md` for custom interactions
6. 🚀 Build your workflow application!

---

## Support

- **Issues**: Report bugs at the repository
- **Examples**: See the `/demo` application
- **Documentation**: Check `.md` files in the project root

## License

MIT License - See LICENSE file for details.
