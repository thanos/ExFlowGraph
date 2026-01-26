defmodule ExFlowGraph.Repo do
  use Ecto.Repo,
    otp_app: :ex_flow_graph,
    adapter: Ecto.Adapters.Postgres
end
