defmodule ExFlowGraphWeb.ExFlow.Edge do
  @moduledoc """
  Edge component for rendering connections between nodes.

  Displays SVG paths connecting node handles with visual styling
  and interactive capabilities.
  """

  use ExFlowGraphWeb, :html

  attr :id, :string, required: true
  attr :source_id, :string, required: true
  attr :target_id, :string, required: true
  attr :source_x, :integer, required: true
  attr :source_y, :integer, required: true
  attr :target_x, :integer, required: true
  attr :target_y, :integer, required: true

  def edge(assigns) do
    ~H"""
    <path
      id={"exflow-edge-#{@id}"}
      class="exflow-edge stroke-base-content/50 hover:stroke-base-content/80"
      fill="none"
      stroke-width="2"
      d={cubic_bezier_path({@source_x, @source_y}, {@target_x, @target_y})}
      data-edge-id={@id}
      data-source-id={@source_id}
      data-target-id={@target_id}
    />
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
