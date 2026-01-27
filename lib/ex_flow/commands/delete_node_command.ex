defmodule ExFlow.Commands.DeleteNodeCommand do
  @moduledoc """
  Command to delete a node from the graph.
  Stores the node data and connected edges for undo.
  """

  @behaviour ExFlow.Command

  alias ExFlow.Core.Graph

  defstruct [:node_id, :node_data, :connected_edges]

  @type t :: %__MODULE__{
          node_id: String.t(),
          node_data: map() | nil,
          connected_edges: [map()] | nil
        }

  def new(node_id, graph) do
    # Capture node data and connected edges before deletion
    node_data = Graph.get_node(graph, node_id)
    connected_edges = get_connected_edges(graph, node_id)

    %__MODULE__{
      node_id: node_id,
      node_data: node_data,
      connected_edges: connected_edges
    }
  end

  @impl ExFlow.Command
  def execute(%__MODULE__{} = cmd, graph) do
    Graph.delete_node(graph, cmd.node_id)
  end

  @impl ExFlow.Command
  def undo(%__MODULE__{} = cmd, graph) do
    # Restore the node
    with {:ok, graph} <-
           Graph.add_node(
             graph,
             cmd.node_id,
             cmd.node_data.type,
             cmd.node_data.metadata
           ) do
      # Restore connected edges
      restore_edges(graph, cmd.connected_edges)
    end
  end

  @impl ExFlow.Command
  def description(%__MODULE__{} = cmd) do
    "Delete node '#{cmd.node_id}'"
  end

  defp get_connected_edges(graph, node_id) do
    graph
    |> Graph.get_edges()
    |> Enum.filter(fn edge ->
      edge.source == node_id || edge.target == node_id
    end)
  end

  defp restore_edges(graph, edges) do
    Enum.reduce_while(edges, {:ok, graph}, fn edge, {:ok, acc_graph} ->
      case Graph.add_edge(
             acc_graph,
             edge.id,
             edge.source,
             edge.source_handle,
             edge.target,
             edge.target_handle
           ) do
        {:ok, new_graph} -> {:cont, {:ok, new_graph}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
