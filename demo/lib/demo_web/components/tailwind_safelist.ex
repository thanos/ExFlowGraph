defmodule DemoWeb.Components.TailwindSafelist do
  @moduledoc """
  This file exists solely to ensure Tailwind scans and includes CSS classes
  used by ExFlowGraph library components.
  """

  use Phoenix.Component

  def dummy(assigns) do
    ~H"""
    <div class="hidden">
      <!-- Canvas classes -->
      <div class="relative h-[70vh] w-full overflow-hidden rounded-2xl border border-base-300 bg-gradient-to-br from-base-200/40 to-base-100"></div>
      <div class="exflow-container absolute inset-0"></div>

      <!-- Node classes -->
      <div class="exflow-node absolute select-none rounded-lg border bg-base-100/90 shadow-sm backdrop-blur px-3 py-2 text-sm text-base-content cursor-grab active:cursor-grabbing pointer-events-auto transition-all border-primary border-2 ring-2 ring-primary/30 shadow-lg border-base-300"></div>
      <div class="font-medium"></div>
      <div class="mt-2 flex gap-2"></div>
      <span class="exflow-handle exflow-handle-source inline-flex size-2 rounded-full bg-primary cursor-crosshair hover:scale-150 transition-transform"></span>
      <span class="exflow-handle exflow-handle-target inline-flex size-2 rounded-full bg-base-content/40 cursor-crosshair hover:scale-150 transition-transform"></span>

      <!-- Edge classes -->
      <svg><path class="exflow-edge stroke-base-content/50 hover:stroke-base-content/80"></path></svg>
      <svg class="absolute inset-0 z-0 h-full w-full pointer-events-none"></svg>
      <div class="absolute inset-0 z-10 pointer-events-none"></div>
    </div>
    """
  end
end
