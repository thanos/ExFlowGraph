defmodule ExFlowGraphWeb.ExFlow.Edge do
  @moduledoc """
  SVG component for rendering edges (connections) between nodes in a flow graph.

  Edges are rendered as smooth cubic Bezier curves connecting source and target nodes.
  They support selection highlighting and provide click/hover interactions.

  ## Features

  - Smooth cubic Bezier curve rendering
  - Invisible wider hit area for easier clicking
  - Selection highlighting with color change
  - Hover effects for better interactivity
  - Pointer-event handling for click detection

  ## Attributes

  - `id` (required) - Unique identifier for the edge
  - `source_id` (required) - ID of the source node
  - `target_id` (required) - ID of the target node
  - `source_x` (required) - X coordinate of source point
  - `source_y` (required) - Y coordinate of source point
  - `target_x` (required) - X coordinate of target point
  - `target_y` (required) - Y coordinate of target point
  - `selected` - Boolean indicating if edge is selected (default: false)

  ## Rendering

  Each edge consists of two SVG paths:

  1. Invisible wide path (20px stroke) for easier clicking
  2. Visible thin path (2-4px stroke) with styling and hover effects

  The visible path changes color and width when selected.

  ## Example

      <ExFlowGraphWeb.ExFlow.Edge.edge
        id="edge-1"
        source_id="node-1"
        target_id="node-2"
        source_x={100}
        source_y={150}
        target_x={300}
        target_y={250}
        selected={false}
      />

  ## Styling

  The edge appearance can be customized via Tailwind classes:

  - Default: `stroke-base-content/50` with `stroke-2`
  - Hover: `stroke-base-content/80`
  - Selected: `stroke-primary` with `stroke-4`

  ## Curve Algorithm

  Edges use cubic Bezier curves with control points positioned to create
  smooth horizontal curves. The control point offset is calculated as:

      offset = max(abs(target_x - source_x), 80)

  This ensures edges remain visually pleasing even for vertically aligned nodes.

  ## Click Handling

  The invisible wide path captures click events via the `exflow-edge` class.
  The JavaScript hook listens for clicks and emits appropriate LiveView events
  based on modifier keys (option/alt click for editing, etc.).
  """

  use ExFlowGraphWeb, :html

  attr :id, :string, required: true
  attr :source_id, :string, required: true
  attr :target_id, :string, required: true
  attr :source_x, :integer, required: true
  attr :source_y, :integer, required: true
  attr :target_x, :integer, required: true
  attr :target_y, :integer, required: true
  attr :selected, :boolean, default: false

  def edge(assigns) do
    ~H"""
    <g>
      <!-- Invisible wider path for easier clicking -->
      <path
        class="exflow-edge"
        fill="none"
        stroke="transparent"
        stroke-width="20"
        d={cubic_bezier_path({@source_x, @source_y}, {@target_x, @target_y})}
        data-edge-id={@id}
        data-source-id={@source_id}
        data-target-id={@target_id}
        style="cursor: pointer;"
      />
      <!-- Visible path -->
      <path
        id={"exflow-edge-#{@id}"}
        class={[
          "transition-colors",
          if(@selected,
            do: "stroke-primary stroke-4",
            else: "stroke-base-content/50 hover:stroke-base-content/80 stroke-2"
          )
        ]}
        fill="none"
        stroke-width={if(@selected, do: "4", else: "2")}
        d={cubic_bezier_path({@source_x, @source_y}, {@target_x, @target_y})}
        style="pointer-events: none;"
      />
    </g>
    """
  end

  def cubic_bezier_path({sx, sy}, {tx, ty}) do
    d = max(abs(tx - sx), 80)
    c1x = sx + d
    c1y = sy
    c2x = tx - d
    c2y = ty

    "M #{sx} #{sy} C #{c1x} #{c1y}, #{c2x} #{c2y}, #{tx} #{ty}"
  end
end
