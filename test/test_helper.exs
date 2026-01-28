ExUnit.start()

# Set up Mox for testing
Mox.defmock(ExFlow.Storage.Mock, for: ExFlow.Storage)
Mox.defmock(ExFlow.RepoMock, for: ExFlow.RepoBehaviour)

# Start the ExFlow application (without database)
Application.ensure_all_started(:ex_flow)
