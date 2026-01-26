defmodule ExFlowGraphWeb.ExFlow.Node do
  use ExFlowGraphWeb, :html

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :x, :integer, default: 0
  attr :y, :integer, default: 0

  def node(assigns) do
    ~H"""
    <div
      class="exflow-node absolute select-none rounded-lg border border-base-300 bg-base-100/90 shadow-sm backdrop-blur px-3 py-2 text-sm text-base-content cursor-grab active:cursor-grabbing"
      data-id={@id}
      data-x={@x}
      data-y={@y}
      style={"transform: translate(#{@x}px, #{@y}px);"}
    >
      <div class="font-medium">{@title}</div>
      <div class="mt-2 flex gap-2">
        <span
          class="exflow-handle exflow-handle-source inline-flex size-2 rounded-full bg-primary"
          data-handle="out"
        />
        <span
          class="exflow-handle exflow-handle-target inline-flex size-2 rounded-full bg-base-content/40"
          data-handle="in"
        />
      </div>
    </div>
    """
  end
end
