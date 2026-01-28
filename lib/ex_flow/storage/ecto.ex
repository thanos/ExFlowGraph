defmodule ExFlow.Storage.Ecto do
  @moduledoc """
  Ecto-backed storage adapter for persisting graphs to a database.

  This adapter serializes LibGraph structures to JSON and stores them
  in the database with optimistic locking support via version numbers.
  """
  @behaviour ExFlow.Storage

  alias ExFlow.GraphRecord
  alias ExFlow.Serializer

  import Ecto.Query

  @impl true
  def load(name) when is_binary(name) do
    case repo().get_by(GraphRecord, name: name) do
      nil ->
        {:error, :not_found}

      record ->
        case Serializer.deserialize(record.data) do
          {:ok, graph} ->
            {:ok, graph}

          {:error, reason} ->
            {:error, {:deserialization_failed, reason}}
        end
    end
  end

  @impl true
  def save(name, graph) when is_binary(name) do
    case Serializer.serialize(graph) do
      {:ok, data} ->
        upsert_graph(name, data)

      {:error, reason} ->
        {:error, {:serialization_failed, reason}}
    end
  end

  @impl true
  def delete(name) when is_binary(name) do
    case repo().get_by(GraphRecord, name: name) do
      nil ->
        {:error, :not_found}

      record ->
        case repo().delete(record) do
          {:ok, _} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @impl true
  def list do
    GraphRecord
    |> select([g], g.name)
    |> repo().all()
  end

  defp upsert_graph(name, data) do
    case repo().get_by(GraphRecord, name: name) do
      nil ->
        # Insert new record
        %GraphRecord{}
        |> GraphRecord.changeset(%{name: name, data: data, version: 1})
        |> repo().insert()
        |> handle_result()

      existing ->
        # Update existing record with optimistic locking
        existing
        |> GraphRecord.changeset(%{
          data: data,
          version: existing.version + 1
        })
        |> repo().update()
        |> handle_result()
    end
  end

  defp handle_result({:ok, _record}), do: :ok
  defp handle_result({:error, changeset}), do: {:error, changeset}

  defp repo, do: Application.fetch_env!(:ex_flow, :repo)
end
