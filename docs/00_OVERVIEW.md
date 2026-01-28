# Overview: ExFlowGraph

**Who this is for:** Phoenix LiveView developers who want to add interactive, node-based editors, flow-chart builders, or diagramming tools to their applications.

**What you'll build:** A high-level understanding of what ExFlowGraph does and what a minimal integration looks like.

---

### What is ExFlowGraph?

ExFlowGraph is a LiveView component that lets you build rich, interactive graph editors with minimal boilerplate. It provides a complete client-side and server-side solution for rendering and manipulating nodes and edges, handling user interactions like dragging, panning, and zooming, and communicating changes back to your LiveView process.

Think of it as a "batteries-included" toolkit for visual workflows, state machines, or any other graph-based UI.

### What Problems It Solves

-   **Reduces Frontend Complexity:** You don't need to write complex JavaScript, manage canvas rendering, or handle drag-and-drop logic. The included JavaScript hook does the heavy lifting.
-   **Provides a Stable Server-Side API:** It offers a clean event-based contract for reacting to user actions, so you can focus on your application's business logic, not on parsing client-side event payloads.
-   **Enforces Server-Side Authority:** The server remains the source of truth for the graph's state, making it secure and easy to integrate with your existing Elixir backend and persistence layers.
-   **Extensible by Design:** It provides clear patterns for custom node types, toolbars, and context menus.

### The Minimum Working Integration

At its core, embedding the graph editor is as simple as adding the component to your template and handling events in your LiveView.

**1. Add the component to your HEEx template:**

```heex
<.ex_flow id="my-graph" graph={@graph} on_event={&handle_graph_event/1} />
```

**2. Initialize the graph in your LiveView:**

```elixir
def mount(_params, _session, socket) do
  graph = ExFlow.Graph.new(nodes: [...], edges: [...])
  {:ok, assign(socket, :graph, graph)}
end
```

**3. Handle events from the component:**

```elixir
defp handle_graph_event({:node_dragged, %{id: node_id, position: pos}}, graph) do
  # Update the node's position and return the new graph state.
  # This is a proposed helper function in the ExFlow.Graph module.
  ExFlow.Graph.update_node(graph, node_id, &Map.put(&1, :position, pos))
end
```

This guide will walk you through turning this concept into a fully functional, persisted graph editor.
