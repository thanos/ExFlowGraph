defmodule ExFlow.Storage do
  @moduledoc """
  Behaviour for graph storage backends.

  Defines the interface for saving, loading, and managing graphs.
  Implementations include InMemory and Ecto adapters.
  """

  @callback load(id :: String.t()) :: {:ok, any()} | {:error, term()}
  @callback save(id :: String.t(), graph :: any()) :: :ok | {:error, term()}
  @callback delete(id :: String.t()) :: :ok | {:error, term()}
  @callback list() :: [String.t()]
end
