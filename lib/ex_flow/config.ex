defmodule ExFlow.Config do
  @moduledoc """
  Configuration helpers for ExFlow storage adapters.
  """

  alias ExFlow.Storage.InMemory

  @doc """
  Returns the configured storage adapter module.
  Defaults to InMemory if not configured.
  """
  def storage_adapter do
    Application.get_env(:ex_flow_graph, :storage_adapter, InMemory)
  end
end
