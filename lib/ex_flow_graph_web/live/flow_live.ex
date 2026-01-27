defmodule ExFlowGraphWeb.FlowLive do
  use ExFlowGraphWeb, :live_view

  alias ExFlow.Core.Graph, as: FlowGraph
  alias ExFlow.Storage.InMemory
  alias Graph, as: LibGraph

  @storage_id "demo"

  @impl true
  def mount(_params, _session, socket) do
    graph =
      case InMemory.load(@storage_id) do
        {:ok, %LibGraph{} = graph} ->
          graph

        _ ->
          {:ok, g1} =
            FlowGraph.add_node(FlowGraph.new(), "agent-1", :agent, %{position: %{x: 120, y: 120}})

          {:ok, g2} = FlowGraph.add_node(g1, "task-1", :task, %{position: %{x: 520, y: 260}})
          {:ok, g3} = FlowGraph.add_edge(g2, "edge-1", "agent-1", "out", "task-1", "in")
          g3
      end

    InMemory.save(@storage_id, graph)

    {:ok,
     socket
     |> assign(:page_title, "ExFlow")
     |> assign(:graph, graph)}
  end

  @impl true
  def handle_event("update_position", %{"id" => id, "x" => x, "y" => y}, socket) do
    case FlowGraph.update_node_position(socket.assigns.graph, id, %{x: round(x), y: round(y)}) do
      {:ok, graph} ->
        :ok = InMemory.save(@storage_id, graph)
        {:noreply, assign(socket, :graph, graph)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    nodes = nodes_for_ui(assigns.graph)
    edges = edges_for_ui(assigns.graph, nodes)
    
    IO.puts("\n=== RENDER DEBUG ===")
    IO.inspect(length(nodes), label: "Nodes count")
    IO.inspect(length(edges), label: "Edges count")
    IO.inspect(edges, label: "Edges data")

    assigns = assign(assigns, nodes: nodes, edges: edges)

    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-6xl">
        <div class="flex items-end justify-between gap-6">
          <div>
            <h1 class="text-2xl font-semibold tracking-tight">ExFlow</h1>
            <p class="mt-1 text-sm text-base-content/70">
              Hybrid canvas: HTML nodes + SVG edges. Drag nodes to move • Drag background to pan • Scroll to zoom
            </p>
          </div>
        </div>

        <div class="mt-6">
          <ExFlowGraphWeb.ExFlow.Canvas.canvas id="exflow-canvas" nodes={@nodes} edges={@edges} />
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp nodes_for_ui(%LibGraph{} = graph) do
    for id <- LibGraph.vertices(graph) do
      case LibGraph.vertex_labels(graph, id) do
        [node] when is_map(node) ->
          %{
            id: node.id,
            title: title_for(node),
            x: node.position.x,
            y: node.position.y
          }

        _ ->
          %{
            id: id,
            title: id,
            x: 0,
            y: 0
          }
      end
    end
  end

  defp edges_for_ui(%LibGraph{} = graph, nodes) do
    node_by_id = Map.new(nodes, fn n -> {n.id, n} end)

    graph
    |> FlowGraph.get_edges()
    |> Enum.map(fn edge ->
      source = Map.get(node_by_id, edge.source)
      target = Map.get(node_by_id, edge.target)

      if source && target do
        %{
          id: edge.id,
          source_id: edge.source,
          target_id: edge.target,
          source_x: source.x + 12,
          source_y: source.y + 12,
          target_x: target.x + 12,
          target_y: target.y + 12
        }
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp title_for(%{type: :agent, id: id}), do: "Agent · #{id}"
  defp title_for(%{type: :task, id: id}), do: "Task · #{id}"
  defp title_for(%{id: id}), do: id
end
