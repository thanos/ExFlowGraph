defmodule ExFlowGraphWeb.HomeLive do
  use ExFlowGraphWeb, :live_view

  alias ExFlow.Core.Graph, as: FlowGraph
  alias ExFlow.Storage.InMemory

  @storage_id "demo-graph"

  @impl true
  def mount(_params, _session, socket) do
    # Try to load existing graph or create demo graph
    graph =
      case InMemory.load(@storage_id) do
        {:ok, existing_graph} ->
          existing_graph

        {:error, :not_found} ->
          create_demo_graph()
      end

    socket =
      socket
      |> assign(:graph, graph)
      |> assign(:selected_node_type, :task)
      |> assign(:graph_name, @storage_id)
      |> assign(:saved_graphs, InMemory.list())
      |> assign(:show_save_modal, false)
      |> assign(:show_load_modal, false)
      |> assign(:show_help, false)

    {:ok, socket}
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
  def handle_event(
        "create_edge",
        %{
          "source_id" => source_id,
          "source_handle" => source_handle,
          "target_id" => target_id,
          "target_handle" => target_handle
        },
        socket
      ) do
    edge_id = "edge-#{System.unique_integer([:positive])}"

    case FlowGraph.add_edge(
           socket.assigns.graph,
           edge_id,
           source_id,
           source_handle,
           target_id,
           target_handle
         ) do
      {:ok, graph} ->
        :ok = InMemory.save(@storage_id, graph)
        {:noreply, assign(socket, :graph, graph)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_node", %{"type" => type}, socket) do
    node_type = String.to_existing_atom(type)
    node_id = "#{type}-#{System.unique_integer([:positive])}"

    # Random position for new nodes
    x = :rand.uniform(400) + 50
    y = :rand.uniform(300) + 50

    case FlowGraph.add_node(socket.assigns.graph, node_id, node_type, %{
           position: %{x: x, y: y}
         }) do
      {:ok, graph} ->
        :ok = InMemory.save(@storage_id, graph)
        {:noreply, assign(socket, :graph, graph)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_node", %{"id" => id}, socket) do
    case FlowGraph.delete_node(socket.assigns.graph, id) do
      {:ok, graph} ->
        :ok = InMemory.save(@storage_id, graph)
        {:noreply, assign(socket, :graph, graph)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_graph", _params, socket) do
    graph = FlowGraph.new()
    :ok = InMemory.save(@storage_id, graph)
    {:noreply, assign(socket, :graph, graph)}
  end

  @impl true
  def handle_event("save_graph", %{"name" => name}, socket) do
    :ok = InMemory.save(name, socket.assigns.graph)

    socket =
      socket
      |> assign(:saved_graphs, InMemory.list())
      |> assign(:show_save_modal, false)
      |> put_flash(:info, "Graph saved as '#{name}'")

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_graph", %{"name" => name}, socket) do
    case InMemory.load(name) do
      {:ok, graph} ->
        :ok = InMemory.save(@storage_id, graph)

        socket =
          socket
          |> assign(:graph, graph)
          |> assign(:show_load_modal, false)
          |> put_flash(:info, "Graph '#{name}' loaded")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to load graph")}
    end
  end

  @impl true
  def handle_event("delete_saved_graph", %{"name" => name}, socket) do
    :ok = InMemory.delete(name)

    socket =
      socket
      |> assign(:saved_graphs, InMemory.list())
      |> put_flash(:info, "Graph '#{name}' deleted")

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_save_modal", _params, socket) do
    {:noreply, assign(socket, :show_save_modal, !socket.assigns.show_save_modal)}
  end

  @impl true
  def handle_event("toggle_load_modal", _params, socket) do
    {:noreply, assign(socket, :show_load_modal, !socket.assigns.show_load_modal)}
  end

  @impl true
  def handle_event("toggle_help", _params, socket) do
    {:noreply, assign(socket, :show_help, !socket.assigns.show_help)}
  end

  @impl true
  def render(assigns) do
    nodes = nodes_for_ui(assigns.graph)
    edges = edges_for_ui(assigns.graph, nodes)

    assigns = assign(assigns, nodes: nodes, edges: edges)

    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-base-200 to-base-300">
      <div class="mx-auto max-w-7xl px-4 py-8">
        <%!-- Header --%>
        <div class="mb-8">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-4xl font-bold tracking-tight bg-gradient-to-r from-primary to-secondary bg-clip-text text-transparent">
                ExFlowGraph
              </h1>
              <p class="mt-2 text-base-content/70">
                Visual workflow editor with drag-and-drop nodes, pan/zoom, and database persistence
              </p>
            </div>
            <button
              phx-click="toggle_help"
              class="btn btn-circle btn-ghost"
              title="Help & Features"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
                class="w-6 h-6"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z"
                />
              </svg>
            </button>
          </div>
        </div>

        <%!-- Help Panel --%>
        <%= if @show_help do %>
          <div class="mb-6 rounded-2xl border border-primary/20 bg-base-100 p-6 shadow-lg">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <h2 class="text-xl font-semibold mb-4">Features & Controls</h2>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <h3 class="font-medium text-primary mb-2">Canvas Controls</h3>
                    <ul class="space-y-1 text-sm text-base-content/70">
                      <li>• Drag nodes to reposition</li>
                      <li>• Drag background to pan</li>
                      <li>• Scroll to zoom in/out</li>
                      <li>• Zoom centers on cursor</li>
                    </ul>
                  </div>
                  <div>
                    <h3 class="font-medium text-primary mb-2">Edge Creation</h3>
                    <ul class="space-y-1 text-sm text-base-content/70">
                      <li>• Drag from blue handle (source)</li>
                      <li>• Drop on gray handle (target)</li>
                      <li>• Press Escape to cancel</li>
                      <li>• Edges follow nodes</li>
                    </ul>
                  </div>
                  <div>
                    <h3 class="font-medium text-primary mb-2">Node Management</h3>
                    <ul class="space-y-1 text-sm text-base-content/70">
                      <li>• Add Task or Agent nodes</li>
                      <li>• Delete nodes (removes edges)</li>
                      <li>• Nodes persist on reload</li>
                    </ul>
                  </div>
                  <div>
                    <h3 class="font-medium text-primary mb-2">Graph Persistence</h3>
                    <ul class="space-y-1 text-sm text-base-content/70">
                      <li>• Auto-saves to memory</li>
                      <li>• Save named versions</li>
                      <li>• Load previous graphs</li>
                      <li>• Database-ready (Ecto adapter)</li>
                    </ul>
                  </div>
                </div>
              </div>
              <button phx-click="toggle_help" class="btn btn-sm btn-circle btn-ghost">
                ✕
              </button>
            </div>
          </div>
        <% end %>

        <%!-- Toolbar --%>
        <div class="mb-6 rounded-2xl border border-base-300 bg-base-100 p-4 shadow-sm">
          <div class="flex flex-wrap items-center gap-3">
            <%!-- Add Nodes --%>
            <div class="flex items-center gap-2">
              <span class="text-sm font-medium text-base-content/70">Add Node:</span>
              <button
                phx-click="add_node"
                phx-value-type="task"
                class="btn btn-sm btn-primary gap-2"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="w-4 h-4"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M12 4.5v15m7.5-7.5h-15"
                  />
                </svg>
                Task
              </button>
              <button
                phx-click="add_node"
                phx-value-type="agent"
                class="btn btn-sm btn-secondary gap-2"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="w-4 h-4"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M12 4.5v15m7.5-7.5h-15"
                  />
                </svg>
                Agent
              </button>
            </div>

            <div class="divider divider-horizontal"></div>

            <%!-- Graph Actions --%>
            <div class="flex items-center gap-2">
              <button phx-click="toggle_save_modal" class="btn btn-sm btn-outline gap-2">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="w-4 h-4"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0111.186 0z"
                  />
                </svg>
                Save
              </button>
              <button phx-click="toggle_load_modal" class="btn btn-sm btn-outline gap-2">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="w-4 h-4"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"
                  />
                </svg>
                Load
              </button>
              <button
                phx-click="clear_graph"
                data-confirm="Are you sure you want to clear the graph?"
                class="btn btn-sm btn-outline btn-error gap-2"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="w-4 h-4"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"
                  />
                </svg>
                Clear
              </button>
            </div>

            <div class="divider divider-horizontal"></div>

            <%!-- Stats --%>
            <div class="flex items-center gap-4 text-sm">
              <div class="flex items-center gap-1">
                <span class="font-medium text-base-content/70">Nodes:</span>
                <span class="badge badge-primary">{length(@nodes)}</span>
              </div>
              <div class="flex items-center gap-1">
                <span class="font-medium text-base-content/70">Edges:</span>
                <span class="badge badge-secondary">{length(@edges)}</span>
              </div>
            </div>
          </div>
        </div>

        <%!-- Canvas --%>
        <div class="rounded-2xl border border-base-300 bg-base-100 shadow-lg overflow-hidden">
          <ExFlowGraphWeb.ExFlow.Canvas.canvas id="exflow-canvas" nodes={@nodes} edges={@edges} />
        </div>

        <%!-- Node List --%>
        <%= if length(@nodes) > 0 do %>
          <div class="mt-6 rounded-2xl border border-base-300 bg-base-100 p-6 shadow-sm">
            <h3 class="text-lg font-semibold mb-4">Nodes</h3>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
              <%= for node <- @nodes do %>
                <div class="flex items-center justify-between rounded-lg border border-base-300 bg-base-200/50 px-4 py-3">
                  <div class="flex items-center gap-3">
                    <div class={[
                      "size-3 rounded-full",
                      if(String.contains?(node.id, "task"), do: "bg-primary", else: "bg-secondary")
                    ]}>
                    </div>
                    <div>
                      <div class="font-medium text-sm">{node.title}</div>
                      <div class="text-xs text-base-content/50">
                        ({node.x}, {node.y})
                      </div>
                    </div>
                  </div>
                  <button
                    phx-click="delete_node"
                    phx-value-id={node.id}
                    class="btn btn-xs btn-circle btn-ghost text-error"
                    title="Delete node"
                  >
                    ✕
                  </button>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Save Modal --%>
      <%= if @show_save_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">Save Graph</h3>
            <form phx-submit="save_graph">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Graph Name</span>
                </label>
                <input
                  type="text"
                  name="name"
                  placeholder="my-workflow"
                  class="input input-bordered"
                  required
                />
              </div>
              <div class="modal-action">
                <button type="button" phx-click="toggle_save_modal" class="btn btn-ghost">
                  Cancel
                </button>
                <button type="submit" class="btn btn-primary">Save</button>
              </div>
            </form>
          </div>
          <div class="modal-backdrop" phx-click="toggle_save_modal"></div>
        </div>
      <% end %>

      <%!-- Load Modal --%>
      <%= if @show_load_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">Load Graph</h3>
            <%= if length(@saved_graphs) > 0 do %>
              <div class="space-y-2">
                <%= for graph_name <- @saved_graphs do %>
                  <%= if graph_name != @storage_id do %>
                    <div class="flex items-center justify-between rounded-lg border border-base-300 bg-base-200/50 px-4 py-3">
                      <span class="font-medium">{graph_name}</span>
                      <div class="flex gap-2">
                        <button
                          phx-click="load_graph"
                          phx-value-name={graph_name}
                          class="btn btn-sm btn-primary"
                        >
                          Load
                        </button>
                        <button
                          phx-click="delete_saved_graph"
                          phx-value-name={graph_name}
                          data-confirm={"Delete '#{graph_name}'?"}
                          class="btn btn-sm btn-ghost btn-circle text-error"
                        >
                          ✕
                        </button>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            <% else %>
              <p class="text-center text-base-content/50 py-8">No saved graphs</p>
            <% end %>
            <div class="modal-action">
              <button phx-click="toggle_load_modal" class="btn btn-ghost">Close</button>
            </div>
          </div>
          <div class="modal-backdrop" phx-click="toggle_load_modal"></div>
        </div>
      <% end %>
    </div>
    """
  end

  defp create_demo_graph do
    graph = FlowGraph.new()

    {:ok, graph} =
      FlowGraph.add_node(graph, "agent-1", :agent, %{position: %{x: 120, y: 120}})

    {:ok, graph} =
      FlowGraph.add_node(graph, "task-1", :task, %{position: %{x: 420, y: 260}})

    {:ok, graph} = FlowGraph.add_edge(graph, "edge-1", "agent-1", "out", "task-1", "in")

    :ok = InMemory.save(@storage_id, graph)
    graph
  end

  defp nodes_for_ui(%Graph{} = graph) do
    for node <- FlowGraph.get_nodes(graph) do
      %{
        id: node.id,
        title: title_for(node),
        x: node.position.x,
        y: node.position.y
      }
    end
  end

  defp edges_for_ui(%Graph{} = graph, nodes) do
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
