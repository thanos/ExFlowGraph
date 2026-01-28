defmodule ExFlow.RepoBehaviour do
  @moduledoc """
  Minimal repo behaviour for storage operations.
  
  This allows us to mock database operations in tests without
  requiring a full Ecto.Repo implementation.
  """

  @callback get_by(schema :: module(), keyword()) :: struct() | nil
  @callback insert(changeset :: Ecto.Changeset.t()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback update(changeset :: Ecto.Changeset.t()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback delete(struct :: struct()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback all(query :: Ecto.Query.t()) :: [term()]
end
