defmodule ExFlow.Commands.CreateNodeCommand do
  @moduledoc """
  Command to create a new node in the graph.
  """

  @behaviour ExFlow.Command

  alias ExFlow.Core.Graph

  defstruct [:node_id, :node_type, :metadata]

  @type t :: %__MODULE__{
          node_id: String.t(),
          node_type: atom(),
          metadata: map()
        }

  def new(node_id, node_type, metadata \\ %{}) do
    %__MODULE__{
      node_id: node_id,
      node_type: node_type,
      metadata: metadata
    }
  end

  @impl ExFlow.Command
  def execute(%__MODULE__{} = cmd, graph) do
    Graph.add_node(graph, cmd.node_id, cmd.node_type, cmd.metadata)
  end

  @impl ExFlow.Command
  def undo(%__MODULE__{} = cmd, graph) do
    Graph.delete_node(graph, cmd.node_id)
  end

  @impl ExFlow.Command
  def description(%__MODULE__{} = cmd) do
    "Create #{cmd.node_type} node '#{cmd.node_id}'"
  end
end
