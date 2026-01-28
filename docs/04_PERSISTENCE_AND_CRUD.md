# Persistence and CRUD

**Who this is for:** Developers who want to save and load their graph state to a database or other persistent store.

**What you'll learn:** A recommended architecture for separating graph logic from your LiveView, using Ecto for persistence, and handling concurrency.

---

While the Quickstart guide keeps all logic in the LiveView, a real application requires a more robust architecture. We recommend using a dedicated "context" module to handle all graph persistence and business logic.

### Recommended Architecture: The `GraphContext`

Your LiveView should be responsible for UI and state management, but it shouldn't know *how* the graph is saved.

1.  **LiveView:** Owns the in-memory graph state (`@graph`). It calls the context module to perform actions.
2.  **Context Module (e.g., `Graphs.ex`):** Exposes functions like `get_graph/1`, `save_graph/2`, `update_node_position/3`, etc. It handles all interaction with the database.
3.  **Ecto Schema:** Defines how the graph is stored in the database.

**Why this design?** This separation makes your code more testable, reusable, and easier to reason about. Your LiveView doesn't need to know about Ecto, and your context module doesn't need to know about LiveView.

### Step 1: Create the Ecto Schema and Migration

First, we need a way to store the graph. We'll use a single table with a `data` column to hold the serialized graph.

**Migration File:** `priv/repo/migrations/YYYYMMDDHHMMSS_create_graphs.exs`

```elixir
defmodule MyApp.Repo.Migrations.CreateGraphs do
  use Ecto.Migration

  def change do
    create table(:graphs) do
      add :name, :string, null: false
      add :data, :map, null: false # Stores the serialized graph
      add :version, :integer, default: 1, null: false # For optimistic locking

      timestamps()
    end

    create unique_index(:graphs, [:name])
  end
end
```

Run `mix ecto.migrate`.

**Schema File:** `lib/my_app/graphs/graph_record.ex`

```elixir
defmodule MyApp.Graphs.GraphRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "graphs" do
    field :name, :string
    field :data, :map
    field :version, :integer, default: 1

    timestamps()
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [:name, :data, :version])
    |> validate_required([:name, :data])
    |> optimistic_lock(:version)
  end
end
```

### Step 2: Create the GraphContext

Now, create the context module that will handle all CRUD operations. `ExFlow.Graph.Serializer` provides helpers for converting the graph to and from a plain map.

**File:** `lib/my_app/graphs.ex`

```elixir
defmodule MyApp.Graphs do
  alias MyApp.Repo
  alias MyApp.Graphs.GraphRecord
  alias ExFlow.Graph
  alias ExFlow.Graph.Serializer

  def get_graph_by_name(name) do
    case Repo.get_by(GraphRecord, name: name) do
      nil -> {:error, :not_found}
      record ->
        graph = Serializer.from_map(record.data)
        {:ok, graph, record.version} # Return version for optimistic locking
    end
  end

  def save_graph(name, graph, version) do
    attrs = %{
      name: name,
      data: Serializer.to_map(graph),
      version: version
    }

    # Use an upsert logic
    case Repo.get_by(GraphRecord, name: name) do
      nil ->
        %GraphRecord{}
        |> GraphRecord.changeset(attrs)
        |> Repo.insert()
      record ->
        GraphRecord.changeset(record, attrs)
        |> Repo.update()
    end
  end
end
```

### Step 3: Refactor the LiveView

Finally, update your `GraphLive` to use the new context module.

**File:** `lib/my_app_web/live/graph_live.ex`

```elixir
defmodule MyAppWeb.GraphLive do
  use MyAppWeb, :live_view

  alias ExFlow.Graph
  alias MyApp.Graphs

  @graph_name "my-first-graph"

  @impl true
  def mount(_params, _session, socket) do
    # Load the graph from the DB
    case Graphs.get_graph_by_name(@graph_name) do
      {:ok, graph, version} ->
        socket
        |> assign(:graph, graph)
        |> assign(:graph_version, version) # Store the version
        |> then(&{:ok, &1})
      {:error, :not_found} ->
        # Create a new one if it doesn't exist
        graph = Graph.new()
        {:ok, new_record, version} = Graphs.save_graph(@graph_name, graph, 1)

        socket
        |> assign(:graph, graph)
        |> assign(:graph_version, version)
        |> then(&{:ok, &1})
    end
  end

  defp handle_graph_event({:node_drag_end, %{id: node_id, position: pos}}, graph) do
    # 1. Update the in-memory graph state
    new_graph = Graph.update_node(graph, node_id, fn node -> Map.put(node, :position, pos) end)

    # 2. Persist the change
    # Note: for simplicity, we're not handling save errors here.
    # In a real app, you would handle the {:error, :stale} case.
    Graphs.save_graph(@graph_name, new_graph, @socket.assigns.graph_version)

    # 3. Return the new state to the component
    new_graph
  end

  # ... other handle_graph_event heads ...
end
```

### Concurrency and Optimistic Locking

When `Graphs.save_graph/3` is called, Ecto's `optimistic_lock` will automatically check if the `version` number in the database matches the one we provide. If another user saved a change in the meantime, the `Repo.update()` call will return `{:error, %Ecto.StaleEntryError{}}`.

Your application code must handle this error, typically by notifying the user that the data is stale and they need to reload.
