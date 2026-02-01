defmodule ExFlowGraphWeb.ExFlow.Edge do
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
