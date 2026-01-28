ExUnit.configure(exclude: [integration: true])
ExUnit.start()

# Set up Mox for testing
Mox.defmock(ExFlow.Storage.Mock, for: ExFlow.Storage)
Mox.defmock(ExFlow.RepoMock, for: ExFlow.RepoBehaviour)

# Configure the test repo
# Application.put_env(:ex_flow, :repo, ExFlow.Test.Repo)
# Application.put_env(:ex_flow, ExFlow.Test.Repo,
#   database: "ex_flow_test",
#   username: "postgres",
#   password: "postgres",
#   hostname: System.get_env("POSTGRES_HOST") || "localhost",
#   pool_size: 1
# )

# Start the ExFlow application
#  Application.ensure_all_started(:ex_flow)

# Run migrations for the test repo
# Ecto.Migrator.run(ExFlow.Test.Repo, :up, all: true)

# Setup the sandbox
# Ecto.Adapters.SQL.Sandbox.mode(ExFlow.Test.Repo, :manual)
