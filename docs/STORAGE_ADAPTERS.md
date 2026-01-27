# ExFlow Storage Adapters

ExFlow supports multiple storage backends through a pluggable adapter system. This allows you to choose the persistence strategy that best fits your needs.

## Available Adapters

### 1. InMemory (Default)

The in-memory adapter stores graphs in an Agent process. Data is lost when the application restarts.

**Use cases:**
- Development and testing
- Demos and prototypes
- Temporary workflows

**Configuration:**
```elixir
# config/config.exs
config :ex_flow_graph,
  storage_adapter: ExFlow.Storage.InMemory
```

**Usage:**
```elixir
alias ExFlow.Storage.InMemory

# Save a graph
:ok = InMemory.save("my-graph", graph)

# Load a graph
{:ok, graph} = InMemory.load("my-graph")

# Delete a graph
:ok = InMemory.delete("my-graph")

# List all graphs
names = InMemory.list()
```

### 2. Ecto (Database Persistence)

The Ecto adapter stores graphs in a PostgreSQL database with optimistic locking support.

**Use cases:**
- Production deployments
- Multi-user applications
- Long-term persistence
- Collaboration features

**Setup:**

1. Run the migration:
```bash
mix ecto.migrate
```

2. Configure the adapter:
```elixir
# config/config.exs
config :ex_flow_graph,
  storage_adapter: ExFlow.Storage.Ecto
```

**Usage:**
```elixir
alias ExFlow.Storage.Ecto

# Save a graph (creates or updates)
:ok = Ecto.save("my-graph", graph)

# Load a graph
{:ok, graph} = Ecto.load("my-graph")

# Delete a graph
:ok = Ecto.delete("my-graph")

# List all graphs
names = Ecto.list()
```

**Features:**
- ✅ Automatic serialization/deserialization
- ✅ Optimistic locking via version numbers
- ✅ Unique constraint per graph name
- ✅ Multi-tenancy support (user_id field)
- ✅ Indexed queries for performance

## Database Schema

The Ecto adapter uses the following schema:

```sql
CREATE TABLE graphs (
  id SERIAL PRIMARY KEY,
  name VARCHAR NOT NULL,
  data JSONB NOT NULL,
  version INTEGER DEFAULT 1 NOT NULL,
  user_id INTEGER,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX graphs_name_index ON graphs (name);
CREATE INDEX graphs_user_id_index ON graphs (user_id);
CREATE UNIQUE INDEX graphs_name_user_id_index ON graphs (name, user_id);
```

## Implementing Custom Adapters

You can create your own storage adapter by implementing the `ExFlow.Storage` behaviour:

```elixir
defmodule MyApp.Storage.Custom do
  @behaviour ExFlow.Storage

  @impl true
  def load(id) do
    # Load graph from your storage backend
    {:ok, graph} | {:error, reason}
  end

  @impl true
  def save(id, graph) do
    # Save graph to your storage backend
    :ok | {:error, reason}
  end

  @impl true
  def delete(id) do
    # Delete graph from your storage backend
    :ok | {:error, reason}
  end

  @impl true
  def list do
    # Return list of all graph IDs
    [String.t()]
  end
end
```

Then configure your custom adapter:

```elixir
# config/config.exs
config :ex_flow_graph,
  storage_adapter: MyApp.Storage.Custom
```

## Serialization

ExFlow uses the `ExFlow.Serializer` module to convert between LibGraph structures and JSON-compatible maps.

**Serialization format:**
```elixir
%{
  nodes: [
    %{
      id: "node-1",
      type: :task,
      position: %{x: 100, y: 200},
      metadata: %{}
    }
  ],
  edges: [
    %{
      id: "edge-1",
      source: "node-1",
      source_handle: "out",
      target: "node-2",
      target_handle: "in"
    }
  ]
}
```

The serializer handles both atom and string keys, making it compatible with JSON storage backends.

## Error Handling

All storage adapters return consistent error tuples:

```elixir
# Success
:ok
{:ok, graph}

# Errors
{:error, :not_found}
{:error, :invalid_data}
{:error, {:serialization_failed, reason}}
{:error, {:deserialization_failed, reason}}
{:error, changeset}  # Ecto-specific
```

## Testing

Both adapters include comprehensive test coverage:

```bash
# Test InMemory adapter
mix test test/ex_flow/storage/in_memory_test.exs

# Test Ecto adapter
mix test test/ex_flow/storage/ecto_test.exs

# Test all storage adapters
mix test test/ex_flow/storage/
```

## Performance Considerations

### InMemory
- ⚡ Fastest read/write performance
- ⚠️ Limited by available RAM
- ⚠️ Data lost on restart

### Ecto
- 📊 Scales with database size
- 🔒 ACID guarantees
- 🌐 Supports distributed deployments
- 📈 Indexed queries for fast lookups

## Migration Guide

### From InMemory to Ecto

1. Run the migration:
```bash
mix ecto.migrate
```

2. Export existing graphs:
```elixir
# In IEx
alias ExFlow.Storage.{InMemory, Ecto}

InMemory.list()
|> Enum.each(fn name ->
  {:ok, graph} = InMemory.load(name)
  :ok = Ecto.save(name, graph)
end)
```

3. Update configuration:
```elixir
config :ex_flow_graph,
  storage_adapter: ExFlow.Storage.Ecto
```

4. Restart your application

## Future Adapters

Potential future storage adapters:
- Redis (fast distributed cache)
- S3 (object storage)
- File system (simple file-based storage)
- CouchDB (document database)
- MongoDB (document database)
