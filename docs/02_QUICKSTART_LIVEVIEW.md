# Quickstart: Your First Graph Editor

**Who this is for:** Developers who have installed ExFlowGraph and want to get a working editor on screen as quickly as possible.

**What you'll build:** A LiveView page that renders an interactive graph editor where you can add, move, connect, and delete nodes.

---

This guide walks you through the "hello world" of ExFlowGraph: a fully interactive editor. We'll create a single LiveView to manage everything.

### Step 1: Create a New LiveView

First, let's create a new LiveView for our graph editor.

**File:** `lib/my_app_web/live/graph_live.ex`

```elixir
defmodule MyAppWeb.GraphLive do
  use MyAppWeb, :live_view

  # Define an alias for the proposed Graph data structure
  alias ExFlow.Graph

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold mb-4">My Graph Editor</h1>

      <.ex_flow
        id="my-graph"
        graph={@graph}
        on_event={&handle_graph_event/2}
        class="w-full h-[80vh] border rounded"
      />
    </div>
    """
  end

  # Remainder of the LiveView code will go here...
end
```

And add a route for it in your router:

**File:** `lib/my_app_web/router.ex`

```elixir
# lib/my_app_web/router.ex
scope "/", MyAppWeb do
  pipe_through :browser
  ...
  live "/graph", GraphLive
end
```

### Step 2: Initialize the Graph State

In `mount/3`, we'll create an initial graph. This graph is a simple Elixir map that the component knows how to render. For now, we'll just create one node.

**File:** `lib/my_app_web/live/graph_live.ex`

```elixir
# Inside the GraphLive module...

@impl true
def mount(_params, _session, socket) do
  # In a real app, you would load this from a database.
  # See the Persistence guide for more.
  initial_nodes = [
    %{id: "node-1", type: :default, position: %{x: 100, y: 150}, data: %{label: "Hello, World!"}}
  ]

  graph = Graph.new(nodes: initial_nodes)

  {:ok, assign(socket, :graph, graph)}
end
```

If you start your server and navigate to `/graph`, you should now see a single node on a pannable, zoomable canvas!

### Step 3: Make it Interactive with `handle_graph_event`

The `on_event` assign points to a function that will receive all events from the component. Let's create a single function head to catch all events and log them.

**File:** `lib/my_app_web/live/graph_live.ex`

```elixir
# Inside the GraphLive module...

# This is our central callback for all component events.
defp handle_graph_event({event_type, payload}, graph) do
  IO.inspect({event_type, payload}, label: "Graph Event")
  # For now, we return the graph unchanged.
  graph
end
```

With this in place, try dragging the node. You'll see `:node_dragged` events printed in your server logs.

### Step 4: Implement CRUD Callbacks

Now, let's implement the logic for each event to modify the graph state. We will add function heads to `handle_graph_event/2` for each action. The `on_event` callback should always return the new, updated graph state. The component will re-render automatically.

**File:** `lib/my_app_web/live/graph_live.ex`

```elixir
# Add these function heads to your GraphLive module

defp handle_graph_event({:node_drag_end, %{id: node_id, position: pos}}, graph) do
  # The Graph.update_node/3 helper makes it easy to update a node immutably.
  Graph.update_node(graph, node_id, fn node -> Map.put(node, :position, pos) end)
end

defp handle_graph_event({:edge_created, %{source_node_id: src, target_node_id: tgt, source_port_id: src_h, target_port_id: tgt_h}}, graph) do
  # Create a deterministic ID for the new edge.
  edge_id = "edge-#{src}-#{tgt}-#{src_h}-#{tgt_h}"

  new_edge = %{
    id: edge_id,
    source: src,
    target: tgt,
    source_handle: src_h,
    target_handle: tgt_h,
    data: %{}
  }

  Graph.add_edge(graph, new_edge)
end

defp handle_graph_event({:nodes_deleted, %{ids: node_ids}}, graph) do
  # We can just pipe the delete operations together.
  Enum.reduce(node_ids, graph, &Graph.delete_node(&2, &1))
end

defp handle_graph_event({:edges_deleted, %{ids: edge_ids}}, graph) do
  Enum.reduce(edge_ids, graph, &Graph.delete_edge(&2, &1))
end

# A catch-all for unhandled events
defp handle_graph_event({event_type, _payload}, graph) do
  IO.inspect(event_type, label: "Unhandled Graph Event")
  graph
end
```

**Wait, `handle_event` or `handle_graph_event`?**

The component does **not** use `handle_event/3`. It uses a dedicated callback (`on_event`) that passes the event payload **and the current graph state**.

**Why this design?** This pattern creates a "controlled component". Your LiveView owns the state. The component emits events, and your code decides how to update the state. This makes persistence, validation, and testing much simpler than if the component managed its own state.

### Step 5: Putting It All Together

Here is the complete, copy-paste-ready LiveView.

**File:** `lib/my_app_web/live/graph_live.ex`

```elixir
defmodule MyAppWeb.GraphLive do
  use MyAppWeb, :live_view

  alias ExFlow.Graph

  # --- LiveView Lifecycle ---

  @impl true
  def mount(_params, _session, socket) do
    initial_nodes = [
      %{id: "node-1", type: :default, position: %{x: 100, y: 150}, data: %{label: "Drag Me!"}},
      %{id: "node-2", type: :default, position: %{x: 400, y: 250}, data: %{label: "Connect Me!"}}
    ]

    graph = Graph.new(nodes: initial_nodes)

    {:ok, assign(socket, :graph, graph)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold mb-4">My Graph Editor</h1>
      <p class="text-sm text-gray-600 mb-4">
        Try dragging nodes, connecting them (from the bottom port to the top port), and deleting them (select + backspace).
      </p>

      <.ex_flow
        id="my-graph"
        graph={@graph}
        on_event={&handle_graph_event(&1, @graph)}
        class="w-full h-[80vh] border rounded"
      />
    </div>
    """
  end

  # --- Graph Event Handling ---

  defp handle_graph_event({:node_drag_end, %{id: node_id, position: pos}}, graph) do
    Graph.update_node(graph, node_id, fn node -> Map.put(node, :position, pos) end)
  end

  defp handle_graph_event({:edge_created, %{source_node_id: src, target_node_id: tgt, source_port_id: src_h, target_port_id: tgt_h}}, graph) do
    edge_id = "edge-#{src}-#{tgt}-#{src_h}-#{tgt_h}"
    new_edge = %{id: edge_id, source: src, target: tgt, source_handle: src_h, target_handle: tgt_h, data: %{}}
    Graph.add_edge(graph, new_edge)
  end

  defp handle_graph_event({:nodes_deleted, %{ids: node_ids}}, graph) do
    Enum.reduce(node_ids, graph, &Graph.delete_node(&2, &1))
  end

  defp handle_graph_event({:edges_deleted, %{ids: edge_ids}}, graph) do
    Enum.reduce(edge_ids, graph, &Graph.delete_edge(&2, &1))
  end

  defp handle_graph_event({:unhandled, {event, payload}}, graph) do
    IO.inspect({event, payload}, label: "Unhandled Graph Event")
    graph
  end
end
```

You now have a working, interactive graph editor! The next guides will show you how to persist this state and customize the component's appearance and behavior.
