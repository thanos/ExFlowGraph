### C) Proposed Public API Spec

This spec defines the stable, developer-friendly interface that ExFlowGraph intends to provide. This is the API that the documentation targets, and the implementation will be refactored to match it.

#### 1. Component Entrypoint

-   **Type:** Function Component
-   **Name:** `<.ex_flow />` (or `ExFlowGraphWeb.ExFlow.live_component/1`)
-   **Module Location (Proposed):** `lib/ex_flow_graph_web/components/ex_flow.ex` (replacing the current `canvas.ex`)
-   **Required Assigns:**
    -   `id` (string): A unique DOM ID for the component instance.
    -   `graph` (%ExFlow.Graph{}): The complete graph state.
    -   `on_event` (function): A 2-arity function that receives `({event_type, payload}, current_graph)`. It *must* return the new graph state (`%ExFlow.Graph{}`).
-   **Optional Assigns:**
    -   `read_only` (boolean, default: `false`): If `true`, all user interactions (drag, delete, connect) are disabled.
    -   `class` (string): CSS class to apply to the component's root `div`.
    -   `node_types` (map, default: `%{}`): A map where keys are node `type` atoms and values are function components (`&MyNodeComponent.render/1`) or maps of style/behavior overrides (e.g., `%{class: "bg-red-500"}`).
    -   `snap_to_grid` (boolean, default: `true`): If `true`, nodes snap to a grid when dragged.
    -   `viewport` (map, default: `%{x: 0, y: 0, zoom: 1.0}`): Controls the initial pan and zoom. The component should internally manage this state and emit `:viewport_changed` events.

#### 2. Graph State Contract

The library will provide Elixir structs for a clear, canonical data contract. These structs should be managed and updated using helper functions provided by the `ExFlow.Graph` module.

-   **`%ExFlow.Graph{}`**:
    -   `:nodes` (`list(%ExFlow.Graph.Node{})`): All nodes in the graph.
    -   `:edges` (`list(%ExFlow.Graph.Edge{})`): All edges in the graph.
    -   `:selection` (`%{nodes: MapSet.t(String.t()), edges: MapSet.t(String.t())}`): Currently selected element IDs.
    -   `:viewport` (`%{x: float, y: float, zoom: float}`): Current canvas viewport state.

-   **`%ExFlow.Graph.Node{}`**:
    -   `:id` (`String.t()`, required): Unique identifier.
    -   `:type` (`atom()`, default: `:default`): Node type, for custom rendering.
    -   `:position` (`%{x: float, y: float}`, required): Top-left coordinates.
    -   `:data` (`map()`, default: `%{}`): Arbitrary custom data.
    -   `:ports` (`list(%{id: String.t(), type: :source | :target, position: :top | :bottom | :left | :right})`, default: `[%{id: "in", type: :target, position: :top}, %{id: "out", type: :source, position: :bottom}]`): Defines connection points.

-   **`%ExFlow.Graph.Edge{}`**:
    -   `:id` (`String.t()`, required): Unique identifier.
    -   `:source` (`String.t()`, required): ID of the source node.
    -   `:target` (`String.t()`, required): ID of the target node.
    -   `:source_handle` (`String.t()`, required): ID of the source port.
    -   `:target_handle` (`String.t()`, required): ID of the target port.
    -   `:data` (`map()`, default: `%{}`): Arbitrary custom data.

#### 3. Client->Server Events (Phoenix LiveView Events)

Events are emitted by the JavaScript hook to the LiveView and handled by the `on_event` callback. Payloads are canonical.

| Event                | Payload Schema                                                                                               | Semantics                                                                                                           |
| :------------------- | :----------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------ |
| `:node_dragged`      | `%{id: String.t(), position: %{x: float, y: float}}`                                                         | Fired continuously during drag. For visual feedback; typically not persisted.                                       |
| `:node_drag_end`     | `%{id: String.t(), position: %{x: float, y: float}}`                                                         | Fired once at the end of a drag. Recommended for persisting position changes.                                       |
| `:edge_created`      | `%{source_node_id: String.t(), target_node_id: String.t(), source_port_id: String.t(), target_port_id: String.t()}` | User created a new connection. Requires server-side ID generation.                                                  |
| `:node_created`      | `%{id: String.t(), type: atom(), position: %{x: float, y: float}, data: map()}`                             | User initiated a new node creation (e.g., via toolbar). `id` may be client-generated temporary or server-generated. |
| `:nodes_deleted`     | `%{ids: [String.t()]}`                                                                                       | User deleted one or more selected nodes. Server should also delete connected edges.                                 |
| `:edges_deleted`     | `%{ids: [String.t()]}`                                                                                       | User deleted one or more selected edges.                                                                            |
| `:selection_changed` | `%{nodes: [String.t()], edges: [String.t()]}`                                                                | User changed the selection. For UI feedback or enabling context-specific actions.                                   |
| `:viewport_changed`  | `%{x: float, y: float, zoom: float}`                                                                         | User panned or zoomed. For persisting user view preferences.                                                        |
| `:node_clicked`      | `%{id: String.t(), meta: map()}`                                                                            | User clicked on a node. `meta` contains click details (e.g., `%{shift_key: true}`).                                |
| `:canvas_clicked`    | `%{position: %{x: float, y: float}, meta: map()}`                                                            | User clicked the empty canvas. `meta` contains click details.                                                       |

#### 4. Server-Side Graph Manipulation (Server Authority)

The server is the authoritative source of truth. Updates to the graph are performed by the LiveView by updating the `@graph` assign. The library will provide a dedicated module, `ExFlow.Graph`, with helper functions for immutable graph manipulation.

-   **`ExFlow.Graph.new(opts \ %{})`**: Creates a new graph (e.g., `nodes: [...], edges: [...]`).
-   **`ExFlow.Graph.add_node(graph, node)`**: Adds a new `%ExFlow.Graph.Node{}`.
-   **`ExFlow.Graph.update_node(graph, node_id, update_fn)`**: Updates a node (e.g., `update_fn = &Map.put(&1, :position, %{x,y})`).
-   **`ExFlow.Graph.delete_node(graph, node_id)`**: Deletes a node by ID.
-   **`ExFlow.Graph.add_edge(graph, edge)`**: Adds a new `%ExFlow.Graph.Edge{}`.
-   **`ExFlow.Graph.delete_edge(graph, edge_id)`**: Deletes an edge by ID.
-   **`ExFlow.Graph.get_node(graph, node_id)`**: Retrieves a node.
-   **`ExFlow.Graph.get_edge(graph, edge_id)`**: Retrieves an edge.

#### 5. Extension Points

-   **Custom Node Rendering (`node_types` assign):**
    -   `node_types: %{my_type: &MyAppWeb.MyNodeComponent.render/1}`
    -   The function component receives an `assigns` map with `:node` (`%ExFlow.Graph.Node{}`), `:is_selected`, `:viewport`, etc.
-   **Custom Context Menu (`<:context_menu>` slot):**
    -   Allows injection of a HEEx template into a floating context menu, shown on right-click.
    -   The slot should receive the `%{selected_nodes: [...], selected_edges: [...]}` context.
-   **Custom Toolbar (`<:toolbar>` slot):**
    -   Allows injection of a HEEx template into a fixed toolbar area.
-   **Custom Validation Rules:** Implemented in the LiveView's `on_event` callback. The server is the authority.

---
