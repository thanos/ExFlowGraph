defmodule ExFlow.Command do
  @moduledoc """
  Protocol for undoable commands in ExFlow.

  Each command must implement:
  - execute/2: Apply the command to a graph
  - undo/2: Reverse the command on a graph
  - description/1: Human-readable description of the command
  """

  alias ExFlow.Core.Graph

  @type t :: term()

  @doc """
  Executes the command on the given graph.
  Returns {:ok, new_graph} or {:error, reason}.
  """
  @callback execute(t(), Graph.t()) :: {:ok, Graph.t()} | {:error, term()}

  @doc """
  Undoes the command on the given graph.
  Returns {:ok, new_graph} or {:error, reason}.
  """
  @callback undo(t(), Graph.t()) :: {:ok, Graph.t()} | {:error, term()}

  @doc """
  Returns a human-readable description of the command.
  """
  @callback description(t()) :: String.t()

  @doc """
  Executes a command on a graph.
  """
  def execute(command, graph) do
    command.__struct__.execute(command, graph)
  end

  @doc """
  Undoes a command on a graph.
  """
  def undo(command, graph) do
    command.__struct__.undo(command, graph)
  end

  @doc """
  Gets the description of a command.
  """
  def description(command) do
    command.__struct__.description(command)
  end
end
