defmodule ExFlowGraphWeb.ExFlow.Canvas do
  @moduledoc """
  Interactive canvas component for rendering flow graphs with pan, zoom, and drag capabilities.

  The Canvas component is the main container for displaying nodes and edges in a visual
  flow diagram. It provides interactive features like panning, zooming, node dragging,
  and edge creation through a JavaScript hook.

  ## Features

  - Pan canvas by clicking and dragging the background
  - Zoom in/out with mouse wheel (centered on cursor)
  - Drag nodes to reposition them
  - Create edges by dragging from source to target handles
  - Multi-select nodes with Shift/Cmd+Click
  - Marquee selection by dragging on background
  - Keyboard shortcuts (undo, redo, delete, select all)

  ## Attributes

  - `id` (required) - Unique identifier for the canvas element
  - `nodes` - List of node maps with `:id`, `:title`, `:x`, `:y` keys
  - `edges` - List of edge maps with source/target coordinates
  - `selected_node_ids` - MapSet of selected node IDs
  - `selected_edge_ids` - MapSet of selected edge IDs

  ## Events

  The canvas emits the following Phoenix LiveView events that you should handle:

  - `update_position` - When a node is dragged (params: `id`, `x`, `y`)
  - `create_edge` - When an edge is created (params: `source_id`, `source_handle`, `target_id`, `target_handle`)
  - `select_node` - When a node is clicked (params: `id`, `multi`)
  - `select_edge` - When an edge is clicked (params: `id`, `multi`)
  - `option_click_node` - When a node is Alt/Option+clicked (params: `id`)
  - `option_click_edge` - When an edge is Alt/Option+clicked (params: `id`)
  - `deselect_all` - When background is clicked or Escape is pressed
  - `select_all` - When Cmd/Ctrl+A is pressed
  - `delete_selected` - When Delete/Backspace is pressed with selection
  - `marquee_select` - When marquee selection completes (params: `node_ids`)
  - `undo` - When Cmd/Ctrl+Z is pressed
  - `redo` - When Cmd/Ctrl+Shift+Z is pressed

  ## Example

      <.canvas
        id="my-flow-canvas"
        nodes={@nodes}
        edges={@edges}
        selected_node_ids={@selected_node_ids}
        selected_edge_ids={@selected_edge_ids}
      />

  ## Node Data Format

  Each node in the `nodes` list should be a map:

      %{
        id: "node-1",
        title: "Process Data",
        x: 100,
        y: 150
      }

  ## Edge Data Format

  Each edge in the `edges` list should be a map:

      %{
        id: "edge-1",
        source_id: "node-1",
        target_id: "node-2",
        source_x: 100,
        source_y: 150,
        target_x: 300,
        target_y: 250
      }

  ## JavaScript Hook

  This component requires the `ExFlowCanvas` JavaScript hook to be registered
  in your LiveSocket configuration:

      import ExFlowCanvas from "./hooks/ex_flow"

      const liveSocket = new LiveSocket("/live", Socket, {
        hooks: {ExFlowCanvas}
      })

  ## Styling

  The canvas uses Tailwind CSS classes and can be customized via:

  - `exflow-canvas-bg` - Background gradient pattern
  - `exflow-node` - Individual node styling
  - `exflow-edge` - Edge path styling
  - `exflow-handle` - Connection handle styling

  See the `guides/customization.md` guide for detailed styling examples.
  """

  use ExFlowGraphWeb, :html

  attr :id, :string, required: true
  attr :nodes, :list, default: []
  attr :edges, :list, default: []
  attr :selected_node_ids, :any, default: []
  attr :selected_edge_ids, :any, default: []

  def canvas(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="ExFlowCanvas"
      style="height: 70vh;"
      class="relative w-full overflow-hidden rounded-2xl border border-base-300 bg-gradient-to-br from-base-200/40 to-base-100 exflow-canvas-bg"
      data-selected-ids={Jason.encode!(MapSet.to_list(@selected_node_ids))}
    >
      <div class="exflow-container absolute inset-0">
        <svg class="absolute inset-0 z-0 h-full w-full">
          <%= for edge <- @edges do %>
            <ExFlowGraphWeb.ExFlow.Edge.edge
              id={edge.id}
              source_id={edge.source_id}
              target_id={edge.target_id}
              source_x={edge.source_x}
              source_y={edge.source_y}
              target_x={edge.target_x}
              target_y={edge.target_y}
              selected={MapSet.member?(@selected_edge_ids, edge.id)}
            />
          <% end %>
        </svg>

        <div class="absolute inset-0 z-10 pointer-events-none">
          <%= for node <- @nodes do %>
            <ExFlowGraphWeb.ExFlow.Node.node
              id={node.id}
              title={node.title}
              x={node.x}
              y={node.y}
              selected={MapSet.member?(@selected_node_ids, node.id)}
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
