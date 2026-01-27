defmodule ExFlow.Storage.InMemory do
  @moduledoc """
  In-memory storage adapter for graphs using Agent.

  Stores graphs in memory for fast access during development and testing.
  Data is lost when the application restarts.
  """

  @behaviour ExFlow.Storage

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @impl true
  def load(id) do
    Agent.get(__MODULE__, fn state ->
      case Map.fetch(state, id) do
        {:ok, graph} -> {:ok, graph}
        :error -> {:error, :not_found}
      end
    end)
  end

  @impl true
  def save(id, graph) do
    Agent.update(__MODULE__, &Map.put(&1, id, graph))
    :ok
  end

  @impl true
  def delete(id) do
    Agent.get_and_update(__MODULE__, fn state ->
      case Map.has_key?(state, id) do
        true -> {:ok, Map.delete(state, id)}
        false -> {{:error, :not_found}, state}
      end
    end)
  end

  @impl true
  def list do
    Agent.get(__MODULE__, fn state ->
      Map.keys(state)
    end)
  end
end
