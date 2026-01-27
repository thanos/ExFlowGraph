defmodule ExFlow.Config do
  @moduledoc """
  Configuration helpers for ExFlow storage adapters.
  """

  @doc """
  Returns the configured storage adapter module.
  Defaults to InMemory if not configured.
  """
  def storage_adapter do
    Application.get_env(:ex_flow_graph, :storage_adapter, ExFlow.Storage.InMemory)
  end
end
