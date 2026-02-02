defmodule ExFlowGraphWeb.ExFlow.Node do
  @moduledoc """
  Component for rendering individual nodes in a flow graph.

  Nodes are draggable boxes with connection handles that can be linked via edges.
  They support selection highlighting, drag-and-drop positioning, and handle
  interactions for creating connections.

  ## Features

  - Draggable positioning with visual feedback
  - Selection highlighting with border and ring effects
  - Two connection handles (source and target)
  - Smooth transitions for state changes
  - Click and keyboard interaction support

  ## Attributes

  - `id` (required) - Unique identifier for the node
  - `title` (required) - Display text shown in the node
  - `x` - X coordinate position in pixels (default: 0)
  - `y` - Y coordinate position in pixels (default: 0)
  - `selected` - Boolean indicating if node is selected (default: false)

  ## Connection Handles

  Each node has two connection handles:

  1. **Source Handle** (blue) - Drag from here to create outgoing edges
     - Located on the left side
     - Uses `data-handle="out"` attribute
     - Styled with `bg-primary` color

  2. **Target Handle** (gray) - Drop edges here to complete connections
     - Located on the right side
     - Uses `data-handle="in"` attribute
     - Styled with `bg-base-content/40` color

  ## Example

      <ExFlowGraphWeb.ExFlow.Node.node
        id="node-1"
        title="Process Data"
        x={100}
        y={150}
        selected={false}
      />

  ## Positioning

  Nodes use CSS transforms for positioning, which provides better performance
  than absolute positioning with top/left:

      style="transform: translate(100px, 150px);"

  The position is controlled by the `x` and `y` attributes and is updated
  when the node is dragged.

  ## Selection State

  When selected, nodes display:

  - 2px primary-colored border (`border-primary border-2`)
  - Primary-colored ring effect (`ring-2 ring-primary/30`)
  - Enhanced shadow (`shadow-lg`)

  When not selected:

  - Default border (`border-base-300`)
  - Standard shadow (`shadow-sm`)

  ## Drag Interaction

  Nodes are draggable via the JavaScript hook:

  - Cursor changes to `cursor-grab` on hover
  - Cursor changes to `cursor-grabbing` while dragging
  - Position updates are sent to LiveView via `update_position` events
  - Smooth transitions between states

  ## Data Attributes

  The following data attributes are used by the JavaScript hook:

  - `data-id` - Node identifier for event handling
  - `data-x` - Current X position
  - `data-y` - Current Y position
  - `data-selected` - Selection state

  ## Styling

  Node appearance can be customized via Tailwind classes:

  - Background: `bg-base-100/90 backdrop-blur`
  - Border: `border-base-300` (or `border-primary` when selected)
  - Shadow: `shadow-sm` (or `shadow-lg` when selected)
  - Shape: `rounded-lg`
  - Padding: `px-3 py-2`
  """

  use ExFlowGraphWeb, :html

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :x, :integer, default: 0
  attr :y, :integer, default: 0
  attr :selected, :boolean, default: false

  def node(assigns) do
    ~H"""
    <div
      class={[
        "exflow-node absolute select-none rounded-lg border bg-base-100/90 shadow-sm backdrop-blur px-3 py-2 text-sm text-base-content cursor-grab active:cursor-grabbing pointer-events-auto transition-all",
        if(@selected,
          do: "border-primary border-2 ring-2 ring-primary/30 shadow-lg",
          else: "border-base-300"
        )
      ]}
      data-id={@id}
      data-x={@x}
      data-y={@y}
      data-selected={@selected}
      style={"transform: translate(#{@x}px, #{@y}px);"}
    >
      <div class="font-medium">{@title}</div>
      <div class="mt-2 flex gap-2">
        <span
          class="exflow-handle exflow-handle-source inline-flex size-2 rounded-full bg-primary cursor-crosshair hover:scale-150 transition-transform"
          data-handle="out"
          data-node-id={@id}
        />
        <span
          class="exflow-handle exflow-handle-target inline-flex size-2 rounded-full bg-base-content/40 cursor-crosshair hover:scale-150 transition-transform"
          data-handle="in"
          data-node-id={@id}
        />
      </div>
    </div>
    """
  end
end
