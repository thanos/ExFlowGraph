defmodule ExFlowGraph.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ExFlowGraphWeb.Telemetry,
      ExFlowGraph.Repo,
      {DNSCluster, query: Application.get_env(:ex_flow_graph, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ExFlowGraph.PubSub},
      ExFlow.Storage.InMemory,
      # Start a worker by calling: ExFlowGraph.Worker.start_link(arg)
      # {ExFlowGraph.Worker, arg},
      # Start to serve requests, typically the last entry
      ExFlowGraphWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExFlowGraph.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ExFlowGraphWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
