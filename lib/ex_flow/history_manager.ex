defmodule ExFlow.HistoryManager do
  @moduledoc """
  Manages undo/redo history using a command stack.

  Maintains two stacks:
  - past: commands that have been executed
  - future: commands that have been undone

  When a new command is executed, the future stack is cleared.
  """

  alias ExFlow.Command

  defstruct past: [], future: [], max_size: 50

  @type t :: %__MODULE__{
          past: [Command.t()],
          future: [Command.t()],
          max_size: pos_integer()
        }

  @doc """
  Creates a new history manager with optional max size.
  """
  def new(max_size \\ 50) do
    %__MODULE__{max_size: max_size}
  end

  @doc """
  Executes a command and adds it to history.
  Clears the future stack.
  """
  def execute(history, command, graph) do
    case Command.execute(command, graph) do
      {:ok, new_graph} ->
        new_past = [command | history.past] |> Enum.take(history.max_size)
        new_history = %{history | past: new_past, future: []}
        {:ok, new_history, new_graph}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Undoes the last command if available.
  """
  def undo(history, graph) do
    case history.past do
      [] ->
        {:error, :nothing_to_undo}

      [command | rest_past] ->
        case Command.undo(command, graph) do
          {:ok, new_graph} ->
            new_history = %{
              history
              | past: rest_past,
                future: [command | history.future]
            }

            {:ok, new_history, new_graph}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Redoes the last undone command if available.
  """
  def redo(history, graph) do
    case history.future do
      [] ->
        {:error, :nothing_to_redo}

      [command | rest_future] ->
        case Command.execute(command, graph) do
          {:ok, new_graph} ->
            new_history = %{
              history
              | past: [command | history.past],
                future: rest_future
            }

            {:ok, new_history, new_graph}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Returns true if there are commands to undo.
  """
  def can_undo?(history) do
    history.past != []
  end

  @doc """
  Returns true if there are commands to redo.
  """
  def can_redo?(history) do
    history.future != []
  end

  @doc """
  Returns the description of the next command to undo, if any.
  """
  def next_undo_description(history) do
    case history.past do
      [] -> nil
      [command | _] -> Command.description(command)
    end
  end

  @doc """
  Returns the description of the next command to redo, if any.
  """
  def next_redo_description(history) do
    case history.future do
      [] -> nil
      [command | _] -> Command.description(command)
    end
  end

  @doc """
  Clears all history.
  """
  def clear(history) do
    %{history | past: [], future: []}
  end

  @doc """
  Returns the number of commands in the past stack.
  """
  def past_count(history) do
    length(history.past)
  end

  @doc """
  Returns the number of commands in the future stack.
  """
  def future_count(history) do
    length(history.future)
  end
end
