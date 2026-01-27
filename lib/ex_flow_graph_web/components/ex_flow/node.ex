defmodule ExFlowGraphWeb.ExFlow.Node do
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
