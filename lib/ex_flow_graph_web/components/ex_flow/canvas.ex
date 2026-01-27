defmodule ExFlowGraphWeb.ExFlow.Canvas do
  use ExFlowGraphWeb, :html

  attr :id, :string, required: true
  attr :nodes, :list, default: []
  attr :edges, :list, default: []

  def canvas(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="ExFlowCanvas"
      class="relative h-[70vh] w-full overflow-hidden rounded-2xl border border-base-300 bg-gradient-to-br from-base-200/40 to-base-100 exflow-canvas-bg"
    >
      <svg class="absolute inset-0 z-0 h-full w-full pointer-events-none">
        <%= for edge <- @edges do %>
          <ExFlowGraphWeb.ExFlow.Edge.edge
            id={edge.id}
            source_id={edge.source_id}
            target_id={edge.target_id}
            source_x={edge.source_x}
            source_y={edge.source_y}
            target_x={edge.target_x}
            target_y={edge.target_y}
          />
        <% end %>
      </svg>

      <div class="exflow-container absolute inset-0">
        <div class="absolute inset-0 z-10 pointer-events-none">
          <%= for node <- @nodes do %>
            <ExFlowGraphWeb.ExFlow.Node.node id={node.id} title={node.title} x={node.x} y={node.y} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
