defmodule ExFlow.Commands.MoveNodeCommand do
  @moduledoc """
  Command to move a node to a new position.
  """

  @behaviour ExFlow.Command

  alias ExFlow.Core.Graph

  defstruct [:node_id, :old_position, :new_position]

  @type t :: %__MODULE__{
          node_id: String.t(),
          old_position: %{x: number(), y: number()},
          new_position: %{x: number(), y: number()}
        }

  def new(node_id, old_position, new_position) do
    %__MODULE__{
      node_id: node_id,
      old_position: old_position,
      new_position: new_position
    }
  end

  @impl ExFlow.Command
  def execute(%__MODULE__{} = cmd, graph) do
    Graph.update_node_position(graph, cmd.node_id, cmd.new_position)
  end

  @impl ExFlow.Command
  def undo(%__MODULE__{} = cmd, graph) do
    Graph.update_node_position(graph, cmd.node_id, cmd.old_position)
  end

  @impl ExFlow.Command
  def description(%__MODULE__{} = cmd) do
    "Move node '#{cmd.node_id}'"
  end
end
