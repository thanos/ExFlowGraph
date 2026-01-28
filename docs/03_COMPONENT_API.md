# Component API Reference

**Who this is for:** Developers who have the Quickstart working and want to customize the component's behavior and appearance.

**What you'll learn:** The complete API for the `<.ex_flow>` component, including all assigns, the event contract, and extension points.

---

The ExFlowGraph component is designed to be a flexible and "controlled" component. Your LiveView owns the state, and the component communicates with you through assigns and events.

### Component Usage (`<.ex_flow ... />`)

The component is a function component, invoked as `<.ex_flow>`.

```heex
<.ex_flow
  id="my-graph"
  graph={@graph}
  on_event={&handle_graph_event/2}
  read_only={false}
  class="w-full h-[80vh]"
/>
```

#### Required Assigns

-   `id` (string): A unique DOM ID for the component.
-   `graph` (%ExFlow.Graph{}): The graph state to be rendered. See "Graph State Contract" below.
-   `on_event` (function): A 2-arity function that receives events from the component as `{event_type, payload}` and the current graph state `graph`.
    -   **It must always return the new graph state.**

#### Optional Assigns

-   `read_only` (boolean, default: `false`): If `true`, all user interactions (drag, delete, connect) are disabled.
-   `class` (string): A CSS class to apply to the component's root element.
-   `node_types` (map, default: `%{}`): A map for defining custom node appearances and behaviors. *(See Extensibility)*.
-   `snap_to_grid` (boolean, default: `true`): If `true`, nodes will snap to a grid when dragged.
-   `viewport` (%{x, y, zoom}, default: `%{x: 0, y: 0, zoom: 1.0}`): Controls the initial pan and zoom of the canvas. The component will send `:viewport_changed` events when the user pans or zooms.

### Graph State Contract

The `graph` assign must be a struct or map that conforms to the `ExFlow.Graph` contract.

**`%ExFlow.Graph{}`**

-   `:nodes` (list of `%ExFlow.Graph.Node{}`): The nodes in the graph.
-   `:edges` (list of `%ExFlow.Graph.Edge{}`): The edges connecting the nodes.
-   `:selection` (%{nodes: MapSet, edges: MapSet}): The set of currently selected node and edge IDs.
-   `:viewport` (%{x, y, zoom}): The current camera position and zoom level.

**`%ExFlow.Graph.Node{}`**

-   `:id` (string, required): A unique ID for the node.
-   `:type` (atom, default: `:default`): The node type, used for custom rendering.
-   `:position` (%{x, y}, required): The coordinates of the node's top-left corner.
-   `:data` (map, default: `%{}`): A map for any custom data (e.g., `%{label: "My Node"}`).
-   `:ports` (list of maps): Defines the connection points on a node. Example: `[%{id: "in", type: :target}, %{id: "out", type: :source}]`.

**`%ExFlow.Graph.Edge{}`**

-   `:id` (string, required): A unique ID for the edge.
-   `:source` (string, required): The ID of the source node.
-   `:target` (string, required): The ID of the target node.
-   `:source_handle` (string, required): The ID of the source port.
-   `:target_handle` (string, required): The ID of the target port.
-   `:data` (map, default: `%{}`): A map for any custom data.

### Event Contract (Client -> Server)

Your `on_event` callback will receive the following events.

| Event             | Payload                                                              | Description                                                                 |
| ----------------- | -------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `:node_dragged`   | `%{id: string, position: %{x, y}}`                                   | Fired continuously as a node is dragged.                                    |
| `:node_drag_end`  | `%{id: string, position: %{x, y}}`                                   | Fired once when a node drag is finished. Use this for persistence.          |
| `:edge_created`   | `%{source_node_id, target_node_id, source_port_id, target_port_id}`  | Fired when a user successfully connects two nodes.                          |
| `:node_created`   | `%{id: string, type: atom, position: %{x, y}, data: map}`           | Fired when user initiates new node creation (e.g., via toolbar).            |
| `:nodes_deleted`  | `%{ids: [string]}`                                                   | Fired when one or more selected nodes are deleted (e.g., with backspace).   |
| `:edges_deleted`  | `%{ids: [string]}`                                                   | Fired when one or more selected edges are deleted.                          |
| `:selection_changed` | `%{nodes: [string], edges: [string]}`                               | Fired when the user's selection changes.                                    |
| `:viewport_changed` | `%{x, y, zoom}`                                                      | Fired when the user pans or zooms the canvas.                               |
| `:node_clicked`   | `%{id: string, meta: map}`                                           | Fired when a user clicks on a node. Useful for showing a details pane.      |
| `:canvas_clicked` | `%{position: %{x, y}, meta: map}`                                    | Fired when the user clicks the empty canvas background.                     |

### Extensibility

**Custom Node Types:**

You can define custom appearances for your nodes by passing a `node_types` map. The key is the node `:type`, and the value is a map of overrides or a function component.

```elixir
node_types = %{
  # Example 1: Overrides for a default node
  special: %{
    class: "bg-purple-500 border-purple-700",
    icon: "hero-star" # Uses Heroicons by default
  },
  # Example 2: Fully custom rendering with a function component
  custom_data_node: &MyAppWeb.CustomNodeComponent.render/1
}

# In your template
<.ex_flow graph={@graph} on_event={...} node_types={node_types} />
```

**Custom Toolbars & Menus:**

The component provides slots for injecting your own HEEx content.

```heex
<.ex_flow graph={@graph} on_event={...}>
  <:toolbar>
    <button phx-click="add_node">Add Node</button>
  </:toolbar>
  <:context_menu :let={%{selected_nodes, selected_edges}}>
    <%= if selected_nodes |> Enum.count() == 1 do %>
      <button phx-click="edit_node" phx-value-id={List.first(selected_nodes)}>Edit</button>
    <% end %>
  </:context_menu>
</.ex_flow>
```
The `:context_menu` slot receives the current selection as assigns, allowing you to build context-aware menus.
