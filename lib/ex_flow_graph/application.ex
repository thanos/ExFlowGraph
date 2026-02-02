defmodule ExFlowGraph.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias ExFlow.Storage.InMemory

  @impl true
  def start(_type, _args) do
    children = [
      # Start the in-memory storage for graphs
      InMemory
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExFlowGraph.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
