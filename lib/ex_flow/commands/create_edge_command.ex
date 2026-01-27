defmodule ExFlow.Commands.CreateEdgeCommand do
  @moduledoc """
  Command to create a new edge in the graph.
  """

  @behaviour ExFlow.Command

  alias ExFlow.Core.Graph

  defstruct [:edge_id, :source_id, :source_handle, :target_id, :target_handle]

  @type t :: %__MODULE__{
          edge_id: String.t(),
          source_id: String.t(),
          source_handle: String.t(),
          target_id: String.t(),
          target_handle: String.t()
        }

  def new(edge_id, source_id, source_handle, target_id, target_handle) do
    %__MODULE__{
      edge_id: edge_id,
      source_id: source_id,
      source_handle: source_handle,
      target_id: target_id,
      target_handle: target_handle
    }
  end

  @impl ExFlow.Command
  def execute(%__MODULE__{} = cmd, graph) do
    Graph.add_edge(
      graph,
      cmd.edge_id,
      cmd.source_id,
      cmd.source_handle,
      cmd.target_id,
      cmd.target_handle
    )
  end

  @impl ExFlow.Command
  def undo(%__MODULE__{} = cmd, graph) do
    Graph.delete_edge(graph, cmd.edge_id)
  end

  @impl ExFlow.Command
  def description(%__MODULE__{} = cmd) do
    "Create edge from '#{cmd.source_id}' to '#{cmd.target_id}'"
  end
end
