import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used

# In test we don't send emails
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
alias Swoosh.Adapters.Test

config :ex_flow_graph, ExFlowGraph.Mailer, adapter: Test

config :ex_flow_graph, ExFlowGraph.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "ex_flow_graph_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  # We don't run a server during test. If one is required,
  # you can enable the server option below.
  pool_size: System.schedulers_online() * 2

config :ex_flow_graph, ExFlowGraphWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "3+0A4zjGZ1NDnfWqHxAGvjKEDqyGz/T+aXRqVr91nsNZZJ+V6cHmJmJf1KXY1WB5",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
