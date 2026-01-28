# Recipes

**Who this is for:** Developers who have a working editor and want to implement common, real-world features.

**What you'll learn:** Patterns for building an undo/redo system, a read-only viewer, and a multi-user collaboration experience.

---

This section provides practical, copy-paste-ready recipes for extending your ExFlowGraph editor.

### Recipe: Undo/Redo

ExFlowGraph is designed to integrate with a command-based history system. By tracking each change as a "command," we can easily implement undo and redo.

**Concept:** Instead of modifying the graph directly in our `handle_graph_event/2` callback, we'll create a command struct for each action and pass it to a history manager.

#### 1. Add a History Manager to Your LiveView State

We will use a simple list-based approach for the history.

**File:** `lib/my_app_web/live/graph_live.ex`

```elixir
defmodule MyAppWeb.GraphLive do
  # ... aliases ...

  @impl true
  def mount(_params, _session, socket) do
    # ... graph loading ...
    socket
    |> assign(graph: graph, graph_version: version)
    |> assign(:undo_stack, []) # A list of previous graph states
    |> assign(:redo_stack, []) # A list of undone graph states
    |> then(&{:ok, &1})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      ...
      <div class="flex items-center gap-2">
        <button
          class="px-3 py-1 border rounded"
          phx-click="undo"
          disabled={@undo_stack == []}
        >
          Undo
        </button>
        <button
          class="px-3 py-1 border rounded"
          phx-click="redo"
          disabled={@redo_stack == []}
        >
          Redo
        </button>
      </div>

      <.ex_flow id="my-graph" graph={@graph} on_event={&handle_graph_event(&1, @graph)} />
    </div>
    """
  end
end
```

#### 2. Update `handle_graph_event` to Manage History

We'll wrap our event handler. Before any change, we push the current graph state onto the `undo_stack`.

**File:** `lib/my_app_web/live/graph_live.ex`

```elixir
# In GraphLive...
def handle_event("undo", _, socket) do
  case socket.assigns.undo_stack do
    [] ->
      {:noreply, socket} # Nothing to undo
    [previous_graph | rest_of_undo] ->
      current_graph = socket.assigns.graph
      new_socket =
        socket
        |> assign(:graph, previous_graph)
        |> assign(:undo_stack, rest_of_undo)
        |> update(:redo_stack, &[current_graph | &1])

      {:noreply, new_socket}
  end
end

def handle_event("redo", _, socket) do
  case socket.assigns.redo_stack do
    [] ->
      {:noreply, socket} # Nothing to redo
    [next_graph | rest_of_redo] ->
      current_graph = socket.assigns.graph
      new_socket =
        socket
        |> assign(:graph, next_graph)
        |> assign(:redo_stack, rest_of_redo)
        |> update(:undo_stack, &[current_graph | &1])

      {:noreply, new_socket}
  end
end

defp handle_graph_event({event, payload}, graph) do # Note: This is 2-arity, consistent with earlier examples
  # Process the event to get the next graph state
  next_graph =
    case {event, payload} do
      {:node_drag_end, %{id: id, position: pos}} ->
        Graph.update_node(graph, id, fn node -> Map.put(node, :position, pos) end)
      # ... other event clauses ...
      _ ->
        graph
    end

  # If the graph changed, update the history
  if next_graph != graph do
    socket
    |> assign(:graph, next_graph)
    |> update(:undo_stack, &[graph | &1])
    |> assign(:redo_stack, []) # Clear redo stack on new action
  else
    socket
  end
end
```
**Note:** This is a simplified implementation. The `ExFlow.HistoryManager` that exists in the library can be adapted to provide a more robust, command-based approach.

### Recipe: Read-Only Viewer

This is the simplest recipe. To make the editor a static viewer, just set the `read_only` assign to `true`.

**File:** `lib/my_app_web/live/graph_viewer_live.ex`

```elixir
def render(assigns) do
  ~H"""
  <.ex_flow
    id="read-only-graph"
    graph={@graph}
    on_event={fn _, g -> g end} # A no-op function for read-only
    read_only={true}
  />
  """
end
```

The component's JS hook will prevent all drag, connect, and delete interactions. The `on_event` callback can be a no-op function that simply returns the graph unchanged.

### Recipe: Multi-User Collaboration (Roadmap)

A powerful use case is allowing multiple users to edit the same graph in real-time. This can be achieved with Phoenix PubSub.

**Concept:**

1.  **PubSub Topic:** When a user loads a graph, they subscribe to a PubSub topic for that graph (e.g., `"graph:my-first-graph"`).
2.  **Broadcast Changes:** When a user's `handle_graph_event` callback produces a new graph state, it saves it to the database and then broadcasts the new state to all other subscribers via `Phoenix.PubSub.broadcast/3`.
3.  **Handle Incoming Changes:** Each LiveView needs a `handle_info/2` callback to listen for these broadcasted messages and update its own `@graph` assign.

**File:** `lib/my_app_web/live/graph_live.ex`

```elixir
# In GraphLive...
@graph_topic "graph:my-first-graph"

def mount(_params, _session, socket) do
  # ...
  MyAppWeb.Endpoint.subscribe(@graph_topic)
  # ...
end

defp handle_graph_event({:node_drag_end, payload}, graph) do
  # ... produce next_graph ...

  if next_graph != graph do
    # ... save to db ...
    Phoenix.PubSub.broadcast(MyApp.PubSub, @graph_topic, {:graph_updated, next_graph})
    # ... update socket state ...
  end
  next_graph
end

@impl true
def handle_info({:graph_updated, graph}, socket) do
  # Another user changed the graph; update our own state.
  # Note: A more robust solution would handle cursor positions.
  {:noreply, assign(socket, :graph, graph)}
end
```

This recipe demonstrates the power of keeping the component "controlled" by the LiveView. The component itself doesn't need to know about PubSub; it just re-renders the state it's given.
