defmodule ExFlow.Test.Repo do
  use Ecto.Repo,
    otp_app: :ex_flow,
    adapter: Ecto.Adapters.Postgres
end
