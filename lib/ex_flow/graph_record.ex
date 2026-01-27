defmodule ExFlow.GraphRecord do
  @moduledoc """
  Ecto schema for persisting graphs to the database.

  The graph data is stored as a JSON-serialized map in the `data` field.
  Optimistic locking is supported via the `version` field.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "graphs" do
    field :name, :string
    field :data, :map
    field :version, :integer, default: 1
    field :user_id, :integer

    timestamps()
  end

  @doc """
  Changeset for creating or updating a graph record.
  """
  def changeset(graph_record, attrs) do
    graph_record
    |> cast(attrs, [:name, :data, :version, :user_id])
    |> validate_required([:name, :data])
    |> validate_change(:data, &validate_graph_data/2)
    |> unique_constraint(:name, name: :graphs_name_user_id_index)
  end

  defp validate_graph_data(:data, data) do
    cond do
      not is_map(data) ->
        [data: "must be a map"]

      not (Map.has_key?(data, "nodes") or Map.has_key?(data, :nodes)) ->
        [data: "must contain nodes"]

      not (Map.has_key?(data, "edges") or Map.has_key?(data, :edges)) ->
        [data: "must contain edges"]

      true ->
        []
    end
  end
end
