# Getting Started with ExFlowGraph

This guide will help you install and set up ExFlowGraph in your Phoenix LiveView application.

## Prerequisites

Before you begin, ensure you have:

- **Elixir**: >= 1.16
- **Phoenix**: >= 1.8
- **Phoenix LiveView**: >= 1.0
- **Tailwind CSS**: v4.x (for styling)

## Installation

### Step 1: Add Dependency

Add ExFlowGraph to your `mix.exs` dependencies:

```elixir
# mix.exs
defp deps do
  [
    {:ex_flow_graph, "~> 0.1.0"},
    # Required dependencies (if not already present)
    {:phoenix_live_view, "~> 1.0"},
    {:libgraph, "~> 0.16"},
    {:jason, "~> 1.2"}
  ]
end
```

For local development, use a path dependency:

```elixir
{:ex_flow_graph, path: "../ExFlowGraph"}
```

### Step 2: Install Dependencies

```bash
mix deps.get
mix compile
```

## Configuration

### Import Components

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

### Configure JavaScript Hook

Add the ExFlowCanvas hook to your `assets/js/app.js`:

```javascript
// assets/js/app.js
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

// Import ExFlowCanvas hook
import ExFlowCanvas from "../../deps/ex_flow_graph/assets/js/hooks/ex_flow"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {ExFlowCanvas}  // Register the hook
})

// Connect and expose liveSocket
liveSocket.connect()
window.liveSocket = liveSocket
```

### Configure Tailwind CSS

Update your `assets/css/app.css` to include ExFlowGraph styles:

```css
/* assets/css/app.css */
@import "tailwindcss";
@source "../css";
@source "../js";
@source "../../lib/your_app_web";
@source "../../deps/ex_flow_graph/lib/ex_flow_graph_web";
```

### Create Tailwind Safelist (Important!)

For Tailwind v4, create a safelist file to ensure all component classes are generated:

```elixir
# lib/your_app_web/components/exflow_safelist.ex
defmodule YourAppWeb.Components.ExFlowSafelist do
  use Phoenix.Component

  def safelist(assigns) do
    ~H"""
    <div class="hidden">
      <div class="relative w-full overflow-hidden rounded-2xl border border-base-300 bg-gradient-to-br from-base-200/40 to-base-100 exflow-container absolute inset-0"></div>
      <div class="exflow-node absolute select-none rounded-lg border bg-base-100/90 shadow-sm backdrop-blur px-3 py-2 text-sm text-base-content cursor-grab active:cursor-grabbing pointer-events-auto transition-all border-primary border-2 ring-2 ring-primary/30 shadow-lg border-base-300 font-medium mt-2 flex gap-2"></div>
      <span class="exflow-handle exflow-handle-source inline-flex size-2 rounded-full bg-primary cursor-crosshair hover:scale-150 transition-transform"></span>
      <span class="exflow-handle exflow-handle-target inline-flex size-2 rounded-full bg-base-content/40 cursor-crosshair hover:scale-150 transition-transform"></span>
      <path class="exflow-edge stroke-base-content/50 hover:stroke-base-content/80 transition-colors stroke-primary stroke-2 stroke-4"></path>
    </div>
    """
  end
end
```

### Rebuild Assets

```bash
mix assets.deploy
```

## Create Your First LiveView

Create a new LiveView module to display your graph:

```elixir
# lib/your_app_web/live/flow_live.ex
defmodule YourAppWeb.FlowLive do
  use YourAppWeb, :live_view

  alias ExFlow.Core.Graph, as: FlowGraph
  alias ExFlow.Storage.InMemory

  @storage_id "my_workflow"

  @impl true
  def mount(_params, _session, socket) do
    graph = load_or_create_graph()

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

  # Event Handlers

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
        toggle_selection(socket.assigns.selected_node_ids, id)
      else
        MapSet.new([id])
      end

    {:noreply, assign(socket, :selected_node_ids, selected)}
  end

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

  # Helper Functions

  defp load_or_create_graph do
    case InMemory.load(@storage_id) do
      {:ok, graph} -> graph
      {:error, _} -> create_initial_graph()
    end
  end

  defp create_initial_graph do
    graph = FlowGraph.new()

    {:ok, graph} =
      FlowGraph.add_node(graph, "node-1", :task, %{
        position: %{x: 100, y: 100},
        label: "Start"
      })

    {:ok, graph} =
      FlowGraph.add_node(graph, "node-2", :task, %{
        position: %{x: 400, y: 100},
        label: "Process"
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

  defp toggle_selection(set, id) do
    if MapSet.member?(set, id) do
      MapSet.delete(set, id)
    else
      MapSet.put(set, id)
    end
  end
end
```

## Add Route

Add the LiveView route to your router:

```elixir
# lib/your_app_web/router.ex
scope "/", YourAppWeb do
  pipe_through :browser

  live "/flow", FlowLive
end
```

## Run Your Application

```bash
mix phx.server
```

Visit `http://localhost:4000/flow` to see your graph!

## What's Next?

- Learn about [Labels & Metadata](labels-and-metadata.html) to attach data to nodes and edges
- Explore [Option+Click Events](option-click-events.html) for custom interactions
- Implement [Undo/Redo](undo-redo.html) functionality
- Check out the demo application in `/demo` for a complete example

## Troubleshooting

### Graph Not Displaying

If your canvas shows but nodes/edges are invisible:

1. Verify the `@source` directive in `assets/css/app.css`
2. Create the safelist file as shown above
3. Run `mix assets.deploy` to rebuild assets
4. Hard refresh your browser (Ctrl+Shift+R)

### JavaScript Hook Not Working

If you can't drag nodes or create edges:

1. Check that the hook is imported in `app.js`
2. Verify `hooks: {ExFlowCanvas}` in LiveSocket config
3. Ensure `phx-hook="ExFlowCanvas"` is on the canvas div
4. Check browser console for JavaScript errors

### Canvas Has Zero Height

Add an inline style to the canvas:

```heex
<ExFlowGraphWeb.ExFlow.Canvas.canvas
  style="height: 70vh;"
  ...
/>
```

## Demo Application

The complete demo application is available in the `/demo` directory. It includes:

- Full workflow editor
- Undo/Redo
- Save/Load functionality
- Edit modals
- Keyboard shortcuts
- And much more!

Reference the demo code for advanced implementations.
