defmodule ExFlow.Commands.DeleteEdgeCommand do
  @moduledoc """
  Command to delete an edge from the graph.
  Stores the edge data for undo.
  """

  @behaviour ExFlow.Command

  alias ExFlow.Core.Graph

  defstruct [:edge_id, :edge_data]

  @type t :: %__MODULE__{
          edge_id: String.t(),
          edge_data: map() | nil
        }

  def new(edge_id, graph) do
    # Capture edge data before deletion
    edge_data =
      graph
      |> Graph.get_edges()
      |> Enum.find(fn edge -> edge.id == edge_id end)

    %__MODULE__{
      edge_id: edge_id,
      edge_data: edge_data
    }
  end

  @impl ExFlow.Command
  def execute(%__MODULE__{} = cmd, graph) do
    Graph.delete_edge(graph, cmd.edge_id)
  end

  @impl ExFlow.Command
  def undo(%__MODULE__{} = cmd, graph) do
    Graph.add_edge(
      graph,
      cmd.edge_id,
      cmd.edge_data.source,
      cmd.edge_data.source_handle,
      cmd.edge_data.target,
      cmd.edge_data.target_handle
    )
  end

  @impl ExFlow.Command
  def description(%__MODULE__{} = cmd) do
    "Delete edge '#{cmd.edge_id}'"
  end
end
