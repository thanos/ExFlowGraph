defmodule ExFlow.Storage.InMemory do
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
end
