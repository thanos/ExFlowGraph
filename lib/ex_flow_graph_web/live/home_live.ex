defmodule ExFlowGraphWeb.HomeLive do
  use ExFlowGraphWeb, :live_view

  alias ExFlow.Core.Graph, as: FlowGraph
  alias ExFlow.Storage.InMemory
  alias ExFlowGraphWeb.Live.Collaboration
  alias ExFlowGraphWeb.Presence

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

    # Set up collaboration
    {user_id, user_color} =
      if connected?(socket) do
        Collaboration.subscribe(@storage_id)

        # Generate user identity
        user_id = Collaboration.get_user_id(socket)
        user_color = Collaboration.generate_user_color()

        # Track presence
        {:ok, _} =
          Presence.track(self(), Collaboration.graph_topic(@storage_id), user_id, %{
            name: "User #{String.slice(user_id, -4..-1)}",
            color: user_color,
            cursor: %{x: 0, y: 0},
            locked_nodes: [],
            online_at: System.system_time(:second)
          })

        {user_id, user_color}
      else
        {nil, nil}
      end

    socket =
      socket
      |> assign(:graph, graph)
      |> assign(:selected_node_type, :task)
      |> assign(:current_graph_name, @storage_id)
      |> assign(:saved_graphs, InMemory.list())
      |> assign(:show_save_modal, false)
      |> assign(:show_save_as_modal, false)
      |> assign(:show_load_modal, false)
      |> assign(:show_help, false)
      |> assign(:selected_node_ids, MapSet.new())
      |> assign(:history, ExFlow.HistoryManager.new())
      |> assign(:user_id, user_id)
      |> assign(:user_color, user_color)
      |> assign(:active_users, %{})
      |> assign(:remote_cursors, %{})
      |> assign(:locked_nodes, MapSet.new())

    {:ok, socket}
  end

  @impl true
  def handle_event("update_position", %{"id" => id, "x" => x, "y" => y}, socket) do
    position = %{x: round(x), y: round(y)}

    case FlowGraph.update_node_position(socket.assigns.graph, id, position) do
      {:ok, graph} ->
        :ok = InMemory.save(@storage_id, graph)

        # Broadcast to other users
        if socket.assigns.user_id do
          Collaboration.broadcast_node_moved(@storage_id, socket.assigns.user_id, id, position)
        end

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

    command =
      ExFlow.Commands.CreateEdgeCommand.new(
        edge_id,
        source_id,
        source_handle,
        target_id,
        target_handle
      )

    case ExFlow.HistoryManager.execute(socket.assigns.history, command, socket.assigns.graph) do
      {:ok, history, graph} ->
        :ok = InMemory.save(@storage_id, graph)

        # Broadcast to other users
        if socket.assigns.user_id do
          edge = %{
            id: edge_id,
            source: source_id,
            source_handle: source_handle,
            target: target_id,
            target_handle: target_handle
          }

          Collaboration.broadcast_edge_created(@storage_id, socket.assigns.user_id, edge)
        end

        {:noreply, assign(socket, graph: graph, history: history)}

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

    command =
      ExFlow.Commands.CreateNodeCommand.new(node_id, node_type, %{position: %{x: x, y: y}})

    case ExFlow.HistoryManager.execute(socket.assigns.history, command, socket.assigns.graph) do
      {:ok, history, graph} ->
        :ok = InMemory.save(@storage_id, graph)

        # Broadcast to other users
        if socket.assigns.user_id do
          {:ok, node} = FlowGraph.get_node(graph, node_id)
          Collaboration.broadcast_node_created(@storage_id, socket.assigns.user_id, node)
        end

        {:noreply, assign(socket, graph: graph, history: history)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_node", %{"id" => id}, socket) do
    command = ExFlow.Commands.DeleteNodeCommand.new(id, socket.assigns.graph)

    case ExFlow.HistoryManager.execute(socket.assigns.history, command, socket.assigns.graph) do
      {:ok, history, graph} ->
        :ok = InMemory.save(@storage_id, graph)

        # Broadcast to other users
        if socket.assigns.user_id do
          Collaboration.broadcast_node_deleted(@storage_id, socket.assigns.user_id, id)
        end

        {:noreply, assign(socket, graph: graph, history: history)}

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
  def handle_event("save_graph", _params, socket) do
    # Save updates the current graph
    name = socket.assigns.current_graph_name
    :ok = InMemory.save(name, socket.assigns.graph)

    socket =
      socket
      |> assign(:saved_graphs, InMemory.list())
      |> put_flash(:info, "Graph '#{name}' updated")

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_as_graph", %{"name" => name}, socket) do
    # Save As creates a new copy with a different name
    :ok = InMemory.save(name, socket.assigns.graph)

    socket =
      socket
      |> assign(:current_graph_name, name)
      |> assign(:saved_graphs, InMemory.list())
      |> assign(:show_save_as_modal, false)
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
          |> assign(:current_graph_name, name)
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
  def handle_event("toggle_save_as_modal", _params, socket) do
    {:noreply, assign(socket, :show_save_as_modal, !socket.assigns.show_save_as_modal)}
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
  def handle_event("load_test_graph", %{"size" => size}, socket) do
    alias ExFlow.TestGraphGenerator

    {:ok, graph} =
      case size do
        "small" -> TestGraphGenerator.small_graph()
        "medium" -> TestGraphGenerator.stress_test_graph()
        "large" -> TestGraphGenerator.large_graph()
        _ -> TestGraphGenerator.small_graph()
      end

    :ok = InMemory.save(@storage_id, graph)

    socket =
      socket
      |> assign(:graph, graph)
      |> assign(:selected_node_ids, MapSet.new())
      |> put_flash(:info, "Loaded #{size} test graph")

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_node", %{"id" => id, "multi" => multi}, socket) do
    selected =
      if multi == "true" do
        # Multi-select: toggle the node
        if MapSet.member?(socket.assigns.selected_node_ids, id) do
          MapSet.delete(socket.assigns.selected_node_ids, id)
        else
          MapSet.put(socket.assigns.selected_node_ids, id)
        end
      else
        # Single select: replace selection
        MapSet.new([id])
      end

    {:noreply, assign(socket, :selected_node_ids, selected)}
  end

  @impl true
  def handle_event("deselect_all", _params, socket) do
    {:noreply, assign(socket, :selected_node_ids, MapSet.new())}
  end

  @impl true
  def handle_event("select_all", _params, socket) do
    all_node_ids =
      socket.assigns.graph
      |> FlowGraph.get_nodes()
      |> Enum.map(& &1.id)
      |> MapSet.new()

    {:noreply, assign(socket, :selected_node_ids, all_node_ids)}
  end

  @impl true
  def handle_event("delete_selected", _params, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_node_ids)

    # Delete each node using commands so they can be undone
    result =
      Enum.reduce_while(selected_ids, {:ok, socket.assigns.history, socket.assigns.graph}, fn id,
                                                                                              {:ok,
                                                                                               acc_history,
                                                                                               acc_graph} ->
        command = ExFlow.Commands.DeleteNodeCommand.new(id, acc_graph)

        case ExFlow.HistoryManager.execute(acc_history, command, acc_graph) do
          {:ok, new_history, new_graph} -> {:cont, {:ok, new_history, new_graph}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case result do
      {:ok, history, graph} ->
        :ok = InMemory.save(@storage_id, graph)

        # Broadcast deletions to other users
        if socket.assigns.user_id do
          Enum.each(selected_ids, fn id ->
            Collaboration.broadcast_node_deleted(@storage_id, socket.assigns.user_id, id)
          end)
        end

        socket =
          socket
          |> assign(:graph, graph)
          |> assign(:history, history)
          |> assign(:selected_node_ids, MapSet.new())
          |> put_flash(:info, "Deleted #{length(selected_ids)} node(s)")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete nodes")}
    end
  end

  @impl true
  def handle_event("marquee_select", %{"node_ids" => node_ids}, socket) do
    selected = MapSet.new(node_ids)
    {:noreply, assign(socket, :selected_node_ids, selected)}
  end

  @impl true
  def handle_event("undo", _params, socket) do
    old_graph = socket.assigns.graph

    case ExFlow.HistoryManager.undo(socket.assigns.history, socket.assigns.graph) do
      {:ok, history, graph} ->
        :ok = InMemory.save(@storage_id, graph)

        # Broadcast changes to other users
        if socket.assigns.user_id do
          broadcast_graph_diff(old_graph, graph, socket.assigns.user_id)
        end

        socket =
          socket
          |> assign(graph: graph, history: history)
          |> put_flash(:info, "Undone: #{ExFlow.HistoryManager.next_redo_description(history)}")

        {:noreply, socket}

      {:error, :nothing_to_undo} ->
        {:noreply, put_flash(socket, :info, "Nothing to undo")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to undo")}
    end
  end

  @impl true
  def handle_event("redo", _params, socket) do
    old_graph = socket.assigns.graph

    case ExFlow.HistoryManager.redo(socket.assigns.history, socket.assigns.graph) do
      {:ok, history, graph} ->
        :ok = InMemory.save(@storage_id, graph)

        # Broadcast changes to other users
        if socket.assigns.user_id do
          broadcast_graph_diff(old_graph, graph, socket.assigns.user_id)
        end

        socket =
          socket
          |> assign(graph: graph, history: history)
          |> put_flash(:info, "Redone: #{ExFlow.HistoryManager.next_undo_description(history)}")

        {:noreply, socket}

      {:error, :nothing_to_redo} ->
        {:noreply, put_flash(socket, :info, "Nothing to redo")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to redo")}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    # Update active users list
    active_users =
      Presence.list(Collaboration.graph_topic(@storage_id))
      |> Enum.into(%{}, fn {user_id, %{metas: [meta | _]}} ->
        {user_id, meta}
      end)

    {:noreply, assign(socket, :active_users, active_users)}
  end

  @impl true
  def handle_info({:cursor_moved, %{user_id: user_id, x: x, y: y}}, socket) do
    # Don't process our own cursor
    if user_id == socket.assigns.user_id do
      {:noreply, socket}
    else
      remote_cursors = Map.put(socket.assigns.remote_cursors, user_id, %{x: x, y: y})
      {:noreply, assign(socket, :remote_cursors, remote_cursors)}
    end
  end

  @impl true
  def handle_info({:node_locked, %{user_id: user_id, node_id: node_id}}, socket) do
    # Don't process our own locks
    if user_id == socket.assigns.user_id do
      {:noreply, socket}
    else
      locked_nodes = MapSet.put(socket.assigns.locked_nodes, node_id)
      {:noreply, assign(socket, :locked_nodes, locked_nodes)}
    end
  end

  @impl true
  def handle_info({:node_unlocked, %{user_id: user_id, node_id: node_id}}, socket) do
    # Don't process our own unlocks
    if user_id == socket.assigns.user_id do
      {:noreply, socket}
    else
      locked_nodes = MapSet.delete(socket.assigns.locked_nodes, node_id)
      {:noreply, assign(socket, :locked_nodes, locked_nodes)}
    end
  end

  @impl true
  def handle_info({:node_created, %{user_id: user_id, node: node}}, socket) do
    # Don't process our own changes
    if user_id == socket.assigns.user_id do
      {:noreply, socket}
    else
      # Add the node to our graph
      case FlowGraph.add_node(
             socket.assigns.graph,
             node.id,
             node.type,
             %{position: node.position, metadata: node.metadata}
           ) do
        {:ok, graph} ->
          {:noreply, assign(socket, :graph, graph)}

        {:error, _} ->
          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_info({:node_deleted, %{user_id: user_id, node_id: node_id}}, socket) do
    # Don't process our own changes
    if user_id == socket.assigns.user_id do
      {:noreply, socket}
    else
      # Delete the node from our graph
      case FlowGraph.delete_node(socket.assigns.graph, node_id) do
        {:ok, graph} ->
          {:noreply, assign(socket, :graph, graph)}

        {:error, _} ->
          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_info(
        {:node_moved, %{user_id: user_id, node_id: node_id, position: position}},
        socket
      ) do
    # Don't process our own changes
    if user_id == socket.assigns.user_id do
      {:noreply, socket}
    else
      # Update the node position in our graph
      case FlowGraph.update_node_position(socket.assigns.graph, node_id, position) do
        {:ok, graph} ->
          {:noreply, assign(socket, :graph, graph)}

        {:error, _} ->
          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_info({:edge_created, %{user_id: user_id, edge: edge}}, socket) do
    # Don't process our own changes
    if user_id == socket.assigns.user_id do
      {:noreply, socket}
    else
      # Add the edge to our graph
      case FlowGraph.add_edge(
             socket.assigns.graph,
             edge.id,
             edge.source,
             edge.source_handle,
             edge.target,
             edge.target_handle
           ) do
        {:ok, graph} ->
          {:noreply, assign(socket, :graph, graph)}

        {:error, _} ->
          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_info({:edge_deleted, %{user_id: user_id, edge_id: edge_id}}, socket) do
    # Don't process our own changes
    if user_id == socket.assigns.user_id do
      {:noreply, socket}
    else
      # Delete the edge from our graph
      case FlowGraph.delete_edge(socket.assigns.graph, edge_id) do
        {:ok, graph} ->
          {:noreply, assign(socket, :graph, graph)}

        {:error, _} ->
          {:noreply, socket}
      end
    end
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
              <div class="mt-2 flex items-center gap-2">
                <span class="text-sm text-base-content/50">Current Graph:</span>
                <span class="badge badge-primary badge-lg">{@current_graph_name}</span>
              </div>
            </div>

            <%!-- Active Users --%>
            <%= if map_size(@active_users) > 0 do %>
              <div class="flex items-center gap-2">
                <span class="text-sm text-base-content/50">Active Users:</span>
                <div class="flex -space-x-2">
                  <%= for {user_id, user_meta} <- @active_users do %>
                    <div
                      class="avatar placeholder tooltip"
                      data-tip={user_meta.name}
                      style={"border: 2px solid #{user_meta.color}"}
                    >
                      <div
                        class="w-8 h-8 rounded-full"
                        style={"background-color: #{user_meta.color}20"}
                      >
                        <span class="text-xs font-bold" style={"color: #{user_meta.color}"}>
                          {String.slice(user_meta.name, 0..1) |> String.upcase()}
                        </span>
                      </div>
                    </div>
                  <% end %>
                </div>
                <span class="badge badge-sm">{map_size(@active_users)}</span>
              </div>
            <% end %>
          </div>
        </div>

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

            <%!-- Undo/Redo --%>
            <div class="flex items-center gap-2">
              <button
                phx-click="undo"
                class="btn btn-sm btn-ghost gap-2"
                disabled={!ExFlow.HistoryManager.can_undo?(@history)}
                title={ExFlow.HistoryManager.next_undo_description(@history) || "Nothing to undo"}
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
                    d="M9 15L3 9m0 0l6-6M3 9h12a6 6 0 010 12h-3"
                  />
                </svg>
                Undo
              </button>
              <button
                phx-click="redo"
                class="btn btn-sm btn-ghost gap-2"
                disabled={!ExFlow.HistoryManager.can_redo?(@history)}
                title={ExFlow.HistoryManager.next_redo_description(@history) || "Nothing to redo"}
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
                    d="M15 15l6-6m0 0l-6-6m6 6H9a6 6 0 000 12h3"
                  />
                </svg>
                Redo
              </button>
            </div>

            <div class="divider divider-horizontal"></div>

            <%!-- Graph Actions --%>
            <div class="flex items-center gap-2">
              <button phx-click="save_graph" class="btn btn-sm btn-primary gap-2">
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
              <button phx-click="toggle_save_as_modal" class="btn btn-sm btn-outline gap-2">
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
                    d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m3.75 9v6m3-3H9m1.5-12H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"
                  />
                </svg>
                Save As
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

            <%!-- Test Graphs --%>
            <div class="dropdown dropdown-end">
              <label tabindex="0" class="btn btn-sm btn-ghost gap-2">
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
                    d="M9.75 3.104v5.714a2.25 2.25 0 01-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 014.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0112 15a9.065 9.065 0 00-6.23-.693L5 14.5m14.8.8l1.402 1.402c1.232 1.232.65 3.318-1.067 3.611A48.309 48.309 0 0112 21c-2.773 0-5.491-.235-8.135-.687-1.718-.293-2.3-2.379-1.067-3.61L5 14.5"
                  />
                </svg>
                Test Graphs
              </label>
              <ul
                tabindex="0"
                class="dropdown-content z-[1] menu p-2 shadow-lg bg-base-100 rounded-box w-52 border border-base-300"
              >
                <li>
                  <button phx-click="load_test_graph" phx-value-size="small">
                    Small (50 nodes)
                  </button>
                </li>
                <li>
                  <button phx-click="load_test_graph" phx-value-size="medium">
                    Medium (500 nodes)
                  </button>
                </li>
                <li>
                  <button phx-click="load_test_graph" phx-value-size="large">
                    Large (1000 nodes)
                  </button>
                </li>
              </ul>
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
              <%= if MapSet.size(@selected_node_ids) > 0 do %>
                <div class="flex items-center gap-1">
                  <span class="font-medium text-base-content/70">Selected:</span>
                  <span class="badge badge-accent">{MapSet.size(@selected_node_ids)}</span>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Canvas --%>
        <div class="rounded-2xl border border-base-300 bg-base-100 shadow-lg overflow-hidden">
          <ExFlowGraphWeb.ExFlow.Canvas.canvas
            id="exflow-canvas"
            nodes={@nodes}
            edges={@edges}
            selected_node_ids={@selected_node_ids}
          />
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

        <%!-- Comprehensive Feature Guide --%>
        <div class="mt-6 rounded-2xl border border-base-300 bg-base-100 p-8 shadow-sm">
          <h2 class="text-2xl font-bold mb-6">Feature Guide & Documentation</h2>

          <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <%!-- Canvas Controls --%>
            <div>
              <h3 class="text-lg font-semibold text-primary mb-4 flex items-center gap-2">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="w-5 h-5"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M15.042 21.672L13.684 16.6m0 0l-2.51 2.225.569-9.47 5.227 7.917-3.286-.672zM12 2.25V4.5m5.834.166l-1.591 1.591M20.25 10.5H18M7.757 14.743l-1.59 1.59M6 10.5H3.75m4.007-4.243l-1.59-1.59"
                  />
                </svg>
                Canvas Controls
              </h3>
              <div class="space-y-3">
                <div class="pl-4 border-l-2 border-primary/30">
                  <h4 class="font-medium mb-1">Pan the Canvas</h4>
                  <p class="text-sm text-base-content/70">
                    Click and drag on the background to move the entire canvas. Perfect for navigating large workflows.
                  </p>
                </div>
                <div class="pl-4 border-l-2 border-primary/30">
                  <h4 class="font-medium mb-1">Zoom In/Out</h4>
                  <p class="text-sm text-base-content/70">
                    Use your mouse wheel to zoom. The zoom centers on your cursor position for precise navigation.
                  </p>
                </div>
                <div class="pl-4 border-l-2 border-primary/30">
                  <h4 class="font-medium mb-1">Move Nodes</h4>
                  <p class="text-sm text-base-content/70">
                    Click and drag any node to reposition it. Connected edges automatically follow the node.
                  </p>
                </div>
              </div>
            </div>

            <%!-- Node Management --%>
            <div>
              <h3 class="text-lg font-semibold text-secondary mb-4 flex items-center gap-2">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="w-5 h-5"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M20.25 6.375c0 2.278-3.694 4.125-8.25 4.125S3.75 8.653 3.75 6.375m16.5 0c0-2.278-3.694-4.125-8.25-4.125S3.75 4.097 3.75 6.375m16.5 0v11.25c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125V6.375m16.5 0v3.75m-16.5-3.75v3.75m16.5 0v3.75C20.25 16.153 16.556 18 12 18s-8.25-1.847-8.25-4.125v-3.75m16.5 0c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125"
                  />
                </svg>
                Node Management
              </h3>
              <div class="space-y-3">
                <div class="pl-4 border-l-2 border-secondary/30">
                  <h4 class="font-medium mb-1">Add Nodes</h4>
                  <p class="text-sm text-base-content/70">
                    Click "Add Task" or "Add Agent" in the toolbar. New nodes appear at random positions and can be dragged immediately.
                  </p>
                </div>
                <div class="pl-4 border-l-2 border-secondary/30">
                  <h4 class="font-medium mb-1">Delete Nodes</h4>
                  <p class="text-sm text-base-content/70">
                    Click the ✕ button on any node in the node list. Deleting a node automatically removes all connected edges.
                  </p>
                </div>
                <div class="pl-4 border-l-2 border-secondary/30">
                  <h4 class="font-medium mb-1">Node Types</h4>
                  <p class="text-sm text-base-content/70">
                    <span class="badge badge-primary badge-sm">Task</span>
                    nodes represent work items.
                    <span class="badge badge-secondary badge-sm">Agent</span>
                    nodes represent actors or services.
                  </p>
                </div>
              </div>
            </div>

            <%!-- Edge Creation --%>
            <div>
              <h3 class="text-lg font-semibold text-accent mb-4 flex items-center gap-2">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="w-5 h-5"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244"
                  />
                </svg>
                Edge Creation
              </h3>
              <div class="space-y-3">
                <div class="pl-4 border-l-2 border-accent/30">
                  <h4 class="font-medium mb-1">Drag to Connect</h4>
                  <p class="text-sm text-base-content/70">
                    Click and drag from a <span class="text-primary font-medium">blue handle</span>
                    (source) to a <span class="text-base-content/50 font-medium">gray handle</span>
                    (target) to create an edge.
                  </p>
                </div>
                <div class="pl-4 border-l-2 border-accent/30">
                  <h4 class="font-medium mb-1">Visual Feedback</h4>
                  <p class="text-sm text-base-content/70">
                    While dragging, you'll see a dashed "ghost edge" following your cursor. Compatible target handles are highlighted.
                  </p>
                </div>
                <div class="pl-4 border-l-2 border-accent/30">
                  <h4 class="font-medium mb-1">Cancel Creation</h4>
                  <p class="text-sm text-base-content/70">
                    Press <kbd class="kbd kbd-xs">Escape</kbd>
                    or release outside a valid target to cancel edge creation.
                  </p>
                </div>
              </div>
            </div>

            <%!-- Undo/Redo --%>
            <div>
              <h3 class="text-lg font-semibold text-warning mb-4 flex items-center gap-2">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="w-5 h-5"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M9 15L3 9m0 0l6-6M3 9h12a6 6 0 010 12h-3"
                  />
                </svg>
                Undo/Redo
              </h3>
              <div class="space-y-3">
                <div class="pl-4 border-l-2 border-warning/30">
                  <h4 class="font-medium mb-1">Command History</h4>
                  <p class="text-sm text-base-content/70">
                    Every action (create, delete, move) is tracked in a command history with up to 50 operations.
                  </p>
                </div>
                <div class="pl-4 border-l-2 border-warning/30">
                  <h4 class="font-medium mb-1">Undo/Redo Operations</h4>
                  <p class="text-sm text-base-content/70">
                    <kbd class="kbd kbd-xs">Cmd/Ctrl+Z</kbd>
                    Undo last action • <kbd class="kbd kbd-xs">Cmd/Ctrl+Shift+Z</kbd>
                    Redo undone action
                  </p>
                </div>
                <div class="pl-4 border-l-2 border-warning/30">
                  <h4 class="font-medium mb-1">Smart Restoration</h4>
                  <p class="text-sm text-base-content/70">
                    Deleting a node and undoing restores both the node and its connected edges.
                  </p>
                </div>
              </div>
            </div>

            <%!-- Selection & Keyboard Shortcuts --%>
            <div>
              <h3 class="text-lg font-semibold text-success mb-4 flex items-center gap-2">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="w-5 h-5"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                Selection & Shortcuts
              </h3>
              <div class="space-y-3">
                <div class="pl-4 border-l-2 border-success/30">
                  <h4 class="font-medium mb-1">Single Selection</h4>
                  <p class="text-sm text-base-content/70">
                    Click a node to select it. Selected nodes have a blue border and ring effect.
                  </p>
                </div>
                <div class="pl-4 border-l-2 border-success/30">
                  <h4 class="font-medium mb-1">Multi-Select</h4>
                  <p class="text-sm text-base-content/70">
                    Hold <kbd class="kbd kbd-xs">Shift</kbd>
                    or <kbd class="kbd kbd-xs">Cmd/Ctrl</kbd>
                    and click to add/remove nodes from selection.
                  </p>
                </div>
                <div class="pl-4 border-l-2 border-success/30">
                  <h4 class="font-medium mb-1">Keyboard Shortcuts</h4>
                  <p class="text-sm text-base-content/70">
                    <kbd class="kbd kbd-xs">Cmd/Ctrl+A</kbd>
                    Select all • <kbd class="kbd kbd-xs">Escape</kbd>
                    Clear selection • <kbd class="kbd kbd-xs">Delete</kbd>
                    Delete selected
                  </p>
                </div>
              </div>
            </div>

            <%!-- Graph Persistence --%>
            <div>
              <h3 class="text-lg font-semibold text-info mb-4 flex items-center gap-2">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="w-5 h-5"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M20.25 6.375c0 2.278-3.694 4.125-8.25 4.125S3.75 8.653 3.75 6.375m16.5 0c0-2.278-3.694-4.125-8.25-4.125S3.75 4.097 3.75 6.375m16.5 0v11.25c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125V6.375m16.5 0v3.75m-16.5-3.75v3.75m16.5 0v3.75C20.25 16.153 16.556 18 12 18s-8.25-1.847-8.25-4.125v-3.75m16.5 0c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125"
                  />
                </svg>
                Graph Persistence
              </h3>
              <div class="space-y-3">
                <div class="pl-4 border-l-2 border-info/30">
                  <h4 class="font-medium mb-1">Auto-Save</h4>
                  <p class="text-sm text-base-content/70">
                    Every change (node move, add, delete, edge creation) is automatically saved to memory.
                  </p>
                </div>
                <div class="pl-4 border-l-2 border-info/30">
                  <h4 class="font-medium mb-1">Save & Save As</h4>
                  <p class="text-sm text-base-content/70">
                    <span class="badge badge-primary badge-sm">Save</span>
                    updates the current graph.
                    <span class="badge badge-outline badge-sm">Save As</span>
                    creates a new copy with a different name.
                  </p>
                </div>
                <div class="pl-4 border-l-2 border-info/30">
                  <h4 class="font-medium mb-1">Load Graphs</h4>
                  <p class="text-sm text-base-content/70">
                    Click "Load" to browse and load any previously saved graph. The current graph is replaced.
                  </p>
                </div>
              </div>
            </div>
          </div>

          <%!-- Technical Details --%>
          <div class="mt-8 pt-8 border-t border-base-300">
            <h3 class="text-lg font-semibold mb-4">Technical Architecture</h3>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div class="space-y-2">
                <h4 class="font-medium text-sm">Frontend</h4>
                <ul class="text-sm text-base-content/70 space-y-1">
                  <li>• Phoenix LiveView</li>
                  <li>• JavaScript Hooks</li>
                  <li>• SVG + HTML rendering</li>
                  <li>• Zero-latency interactions</li>
                </ul>
              </div>
              <div class="space-y-2">
                <h4 class="font-medium text-sm">Backend</h4>
                <ul class="text-sm text-base-content/70 space-y-1">
                  <li>• LibGraph (immutable graphs)</li>
                  <li>• Pluggable storage adapters</li>
                  <li>• InMemory & Ecto adapters</li>
                  <li>• Optimistic locking</li>
                </ul>
              </div>
              <div class="space-y-2">
                <h4 class="font-medium text-sm">Features</h4>
                <ul class="text-sm text-base-content/70 space-y-1">
                  <li>• Drag-and-drop nodes</li>
                  <li>• Pan/zoom canvas</li>
                  <li>• Edge creation</li>
                  <li>• Database persistence</li>
                </ul>
              </div>
            </div>
          </div>

          <%!-- Quick Tips --%>
          <div class="mt-6 rounded-lg bg-primary/5 p-4 border border-primary/20">
            <h4 class="font-semibold text-sm mb-2 flex items-center gap-2">
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
                  d="M12 18v-5.25m0 0a6.01 6.01 0 001.5-.189m-1.5.189a6.01 6.01 0 01-1.5-.189m3.75 7.478a12.06 12.06 0 01-4.5 0m3.75 2.383a14.406 14.406 0 01-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 10-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"
                />
              </svg>
              Pro Tips
            </h4>
            <ul class="text-sm text-base-content/70 space-y-1">
              <li>
                • Hold <kbd class="kbd kbd-xs">Shift</kbd> while dragging for precise node placement
              </li>
              <li>• Use the node list to quickly find and delete specific nodes</li>
              <li>• Create multiple named graphs to organize different workflows</li>
              <li>• The current graph name is shown in the header badge</li>
              <li>• All changes persist across page reloads</li>
            </ul>
          </div>
        </div>
      </div>

      <%!-- Save As Modal --%>
      <%= if @show_save_as_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">Save Graph As</h3>
            <p class="text-sm text-base-content/70 mb-4">
              Create a copy of the current graph with a new name.
            </p>
            <form phx-submit="save_as_graph">
              <div class="form-control">
                <label class="label">
                  <span class="label-text">New Graph Name</span>
                </label>
                <input
                  type="text"
                  name="name"
                  placeholder="my-workflow-v2"
                  class="input input-bordered"
                  required
                />
              </div>
              <div class="modal-action">
                <button type="button" phx-click="toggle_save_as_modal" class="btn btn-ghost">
                  Cancel
                </button>
                <button type="submit" class="btn btn-primary">Save As</button>
              </div>
            </form>
          </div>
          <div class="modal-backdrop" phx-click="toggle_save_as_modal"></div>
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
                  <%= if graph_name != @current_graph_name do %>
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

  # Helper function to broadcast graph differences after undo/redo
  defp broadcast_graph_diff(old_graph, new_graph, user_id) do
    old_nodes = FlowGraph.get_nodes(old_graph) |> Enum.map(& &1.id) |> MapSet.new()
    new_nodes = FlowGraph.get_nodes(new_graph) |> Enum.map(& &1.id) |> MapSet.new()

    old_edges = FlowGraph.get_edges(old_graph) |> Enum.map(& &1.id) |> MapSet.new()
    new_edges = FlowGraph.get_edges(new_graph) |> Enum.map(& &1.id) |> MapSet.new()

    # Broadcast added nodes
    added_nodes = MapSet.difference(new_nodes, old_nodes)

    Enum.each(added_nodes, fn node_id ->
      case FlowGraph.get_node(new_graph, node_id) do
        {:ok, node} ->
          Collaboration.broadcast_node_created(@storage_id, user_id, node)

        {:error, _} ->
          :ok
      end
    end)

    # Broadcast deleted nodes
    deleted_nodes = MapSet.difference(old_nodes, new_nodes)

    Enum.each(deleted_nodes, fn node_id ->
      Collaboration.broadcast_node_deleted(@storage_id, user_id, node_id)
    end)

    # Broadcast moved nodes (nodes that exist in both but may have moved)
    common_nodes = MapSet.intersection(old_nodes, new_nodes)

    Enum.each(common_nodes, fn node_id ->
      with {:ok, old_node} <- FlowGraph.get_node(old_graph, node_id),
           {:ok, new_node} <- FlowGraph.get_node(new_graph, node_id) do
        if old_node.position != new_node.position do
          Collaboration.broadcast_node_moved(@storage_id, user_id, node_id, new_node.position)
        end
      end
    end)

    # Broadcast added edges
    added_edges = MapSet.difference(new_edges, old_edges)

    Enum.each(added_edges, fn edge_id ->
      new_graph
      |> FlowGraph.get_edges()
      |> Enum.find(fn edge -> edge.id == edge_id end)
      |> case do
        nil ->
          :ok

        edge ->
          Collaboration.broadcast_edge_created(@storage_id, user_id, edge)
      end
    end)

    # Broadcast deleted edges
    deleted_edges = MapSet.difference(old_edges, new_edges)

    Enum.each(deleted_edges, fn edge_id ->
      Collaboration.broadcast_edge_deleted(@storage_id, user_id, edge_id)
    end)
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
