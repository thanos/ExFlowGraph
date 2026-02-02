import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used

config :demo, Demo.Mailer, adapter: Test

config :demo, Demo.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "demo_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  # We don't run a server during test. If one is required,
  # you can enable the server option below.
  pool_size: System.schedulers_online() * 2

config :demo, DemoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Z872o+Mc1lhnnPdBY+bd1yrB5FHxxS0sYakYUl/B7nbsmE+k7PteEbN8oCosyo6I",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
