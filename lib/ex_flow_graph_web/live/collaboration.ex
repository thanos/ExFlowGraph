defmodule ExFlowGraphWeb.Live.Collaboration do
  @moduledoc """
  Handles real-time collaboration features for graph editing.

  Provides functions for:
  - PubSub topic management
  - Broadcasting graph changes
  - Presence tracking
  - Cursor sharing
  - Node locking
  """

  alias Phoenix.PubSub
  alias ExFlowGraphWeb.Presence

  @pubsub ExFlowGraph.PubSub

  @doc """
  Returns the PubSub topic for a given graph.
  """
  def graph_topic(graph_id) do
    "graph:#{graph_id}"
  end

  @doc """
  Subscribes the current process to a graph's topic.
  """
  def subscribe(graph_id) do
    PubSub.subscribe(@pubsub, graph_topic(graph_id))
  end

  @doc """
  Unsubscribes the current process from a graph's topic.
  """
  def unsubscribe(graph_id) do
    PubSub.unsubscribe(@pubsub, graph_topic(graph_id))
  end

  @doc """
  Broadcasts a graph change to all subscribers.
  """
  def broadcast_change(graph_id, event, payload) do
    PubSub.broadcast(@pubsub, graph_topic(graph_id), {event, payload})
  end

  @doc """
  Tracks a user's presence in a graph session.
  """
  def track_user(socket, graph_id, user_id, user_meta) do
    Presence.track(socket, user_id, user_meta)
  end

  @doc """
  Updates a user's presence metadata.
  """
  def update_user(socket, user_id, user_meta) do
    Presence.update(socket, user_id, user_meta)
  end

  @doc """
  Lists all users currently present in a graph session.
  """
  def list_users(graph_id) do
    Presence.list(graph_topic(graph_id))
  end

  @doc """
  Broadcasts cursor position update.
  """
  def broadcast_cursor(graph_id, user_id, x, y) do
    broadcast_change(graph_id, :cursor_moved, %{
      user_id: user_id,
      x: x,
      y: y,
      timestamp: System.system_time(:millisecond)
    })
  end

  @doc """
  Broadcasts node lock event.
  """
  def broadcast_lock(graph_id, user_id, node_id) do
    broadcast_change(graph_id, :node_locked, %{
      user_id: user_id,
      node_id: node_id,
      timestamp: System.system_time(:millisecond)
    })
  end

  @doc """
  Broadcasts node unlock event.
  """
  def broadcast_unlock(graph_id, user_id, node_id) do
    broadcast_change(graph_id, :node_unlocked, %{
      user_id: user_id,
      node_id: node_id,
      timestamp: System.system_time(:millisecond)
    })
  end

  @doc """
  Broadcasts a node creation event.
  """
  def broadcast_node_created(graph_id, user_id, node) do
    broadcast_change(graph_id, :node_created, %{
      user_id: user_id,
      node: node,
      timestamp: System.system_time(:millisecond)
    })
  end

  @doc """
  Broadcasts a node deletion event.
  """
  def broadcast_node_deleted(graph_id, user_id, node_id) do
    broadcast_change(graph_id, :node_deleted, %{
      user_id: user_id,
      node_id: node_id,
      timestamp: System.system_time(:millisecond)
    })
  end

  @doc """
  Broadcasts a node position update.
  """
  def broadcast_node_moved(graph_id, user_id, node_id, position) do
    broadcast_change(graph_id, :node_moved, %{
      user_id: user_id,
      node_id: node_id,
      position: position,
      timestamp: System.system_time(:millisecond)
    })
  end

  @doc """
  Broadcasts an edge creation event.
  """
  def broadcast_edge_created(graph_id, user_id, edge) do
    broadcast_change(graph_id, :edge_created, %{
      user_id: user_id,
      edge: edge,
      timestamp: System.system_time(:millisecond)
    })
  end

  @doc """
  Broadcasts an edge deletion event.
  """
  def broadcast_edge_deleted(graph_id, user_id, edge_id) do
    broadcast_change(graph_id, :edge_deleted, %{
      user_id: user_id,
      edge_id: edge_id,
      timestamp: System.system_time(:millisecond)
    })
  end

  @doc """
  Generates a random color for a user.
  """
  def generate_user_color do
    colors = [
      "#3B82F6",
      "#EF4444",
      "#10B981",
      "#F59E0B",
      "#8B5CF6",
      "#EC4899",
      "#14B8A6",
      "#F97316"
    ]

    Enum.random(colors)
  end

  @doc """
  Generates a user ID from the socket session.
  """
  def get_user_id(socket) do
    # In production, this would come from authentication
    # For now, generate a unique ID per session
    socket.id || "user-#{:erlang.unique_integer([:positive])}"
  end
end
