ExUnit.start()

# Set up Mox for testing
Mox.defmock(ExFlow.Storage.Mock, for: ExFlow.Storage)

# Start the ExFlow application
Application.ensure_all_started(:ex_flow)

# Configure the test repo
Application.put_env(:ex_flow, :repo, ExFlow.Test.Repo)

Application.put_env(:ex_flow, ExFlow.Test.Repo,
  database: "ex_flow_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool_size: 1
)

# Only start database if available (for tests that need it)
if Code.ensure_loaded?(ExFlow.Test.Repo) do
  case ExFlow.Test.Repo.start_link() do
    {:ok, _pid} ->
      # Run migrations
      Ecto.Migrator.run(ExFlow.Test.Repo, :up, all: true)
      # Setup the sandbox
      Ecto.Adapters.SQL.Sandbox.mode(ExFlow.Test.Repo, :manual)

    {:error, _} ->
      IO.puts("Database not available - skipping Ecto tests")
  end
end
