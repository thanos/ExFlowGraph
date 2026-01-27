defmodule ExFlow.Storage do
  @callback load(id :: String.t()) :: {:ok, any()} | {:error, term()}
  @callback save(id :: String.t(), graph :: any()) :: :ok | {:error, term()}
  @callback delete(id :: String.t()) :: :ok | {:error, term()}
  @callback list() :: [String.t()]
end
