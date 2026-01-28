# ExFlow Demo Application

A complete Phoenix LiveView application demonstrating how to use ExFlow for building visual flow-based workflows.

## Features

- **Visual Graph Editor** - Drag-and-drop interface for creating workflows
- **Real-time Collaboration** - Multiple users can edit the same workflow simultaneously
- **Persistent Storage** - Save and load workflows from PostgreSQL
- **Undo/Redo** - Full history management for graph operations
- **Example Workflows** - Pre-built templates for common patterns

## Quick Start

### Prerequisites

- Elixir 1.15+ and Erlang/OTP 26+
- PostgreSQL 14+
- Node.js 18+ (for assets)

### Setup

1. **Install dependencies:**

```bash
cd demo
mix deps.get
npm install --prefix assets
```

2. **Create and migrate database:**

```bash
mix ecto.create
mix ecto.migrate
```

3. **Load example workflows:**

```bash
mix run -e "ExFlowGraph.Examples.WorkflowExamples.save_all_examples()"
```

4. **Start the server:**

```bash
mix phx.server
```

5. **Open your browser:**

Visit [http://localhost:4000](http://localhost:4000)

## Using ExFlow in Your Application

### Basic Integration

Add ExFlow to your Phoenix application:

```elixir
# mix.exs
def deps do
  [
    {:ex_flow, path: "../"}  # or from Hex when published
  ]
end
```

### Configuration

Configure storage in `config/config.exs`:

```elixir
# Use database storage
config :ex_flow, :storage, ExFlow.Storage.Ecto
config :ex_flow, :repo, ExFlowGraph.Repo

# Or use in-memory storage for development
config :ex_flow, :storage, ExFlow.Storage.InMemory
```

### Creating Workflows Programmatically

```elixir
# In your application code
defmodule MyApp.Workflows do
  def create_user_onboarding do
    ExFlow.new()
    |> ExFlow.add_node!("welcome", :trigger, 
        x: 0, y: 0, 
        label: "New User Signup")
    |> ExFlow.add_node!("send-email", :task, 
        x: 200, y: 0, 
        label: "Send Welcome Email",
        template: "welcome_email")
    |> ExFlow.add_node!("create-profile", :task, 
        x: 400, y: 0, 
        label: "Create User Profile")
    |> ExFlow.add_node!("assign-defaults", :task, 
        x: 600, y: 0, 
        label: "Assign Default Settings")
    |> ExFlow.add_node!("complete", :output, 
        x: 800, y: 0, 
        label: "Onboarding Complete")
    |> ExFlow.add_edge!("e1", "welcome", "send-email")
    |> ExFlow.add_edge!("e2", "send-email", "create-profile")
    |> ExFlow.add_edge!("e3", "create-profile", "assign-defaults")
    |> ExFlow.add_edge!("e4", "assign-defaults", "complete")
  end

  def save_workflow do
    workflow = create_user_onboarding()
    ExFlow.save(workflow, "user-onboarding")
  end
end
```

### Using in LiveView

```elixir
defmodule MyAppWeb.WorkflowLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    # Load or create a workflow
    graph = case ExFlow.load("my-workflow") do
      {:ok, graph} -> graph
      {:error, :not_found} -> ExFlow.new()
    end

    {:ok, assign(socket, graph: graph)}
  end

  def handle_event("add_node", %{"id" => id, "type" => type}, socket) do
    {:ok, graph} = ExFlow.add_node(socket.assigns.graph, id, String.to_atom(type))
    {:noreply, assign(socket, graph: graph)}
  end

  def handle_event("add_edge", %{"id" => id, "source" => source, "target" => target}, socket) do
    {:ok, graph} = ExFlow.add_edge(socket.assigns.graph, id, source, target)
    {:noreply, assign(socket, graph: graph)}
  end

  def handle_event("save", _params, socket) do
    case ExFlow.save(socket.assigns.graph, "my-workflow") do
      :ok -> 
        {:noreply, put_flash(socket, :info, "Workflow saved!")}
      {:error, reason} -> 
        {:noreply, put_flash(socket, :error, "Failed to save: #{inspect(reason)}")}
    end
  end
end
```

## Example Workflows

The demo includes several pre-built example workflows:

### 1. Simple Sequential

A basic linear workflow demonstrating sequential task execution.

```elixir
{:ok, workflow} = ExFlow.load("simple-sequential")
```

### 2. Conditional Branching

Shows how to implement decision points with multiple paths.

```elixir
{:ok, workflow} = ExFlow.load("conditional-branching")
```

### 3. Parallel Processing

Demonstrates splitting work across multiple parallel tasks.

```elixir
{:ok, workflow} = ExFlow.load("parallel-processing")
```

### 4. ETL Pipeline

A complete Extract-Transform-Load data pipeline.

```elixir
{:ok, workflow} = ExFlow.load("etl-pipeline")
```

### 5. AI Agent Workflow

An autonomous agent with planning and execution capabilities.

```elixir
{:ok, workflow} = ExFlow.load("ai-agent-workflow")
```

### 6. Order Processing

Real-world e-commerce order processing workflow.

```elixir
{:ok, workflow} = ExFlow.load("order-processing")
```

## API Examples

### Creating Nodes

```elixir
# Simple node
{:ok, graph} = ExFlow.add_node(graph, "task-1", :task)

# Node with position
{:ok, graph} = ExFlow.add_node(graph, "task-2", :task, x: 100, y: 200)

# Node with metadata
{:ok, graph} = ExFlow.add_node(graph, "task-3", :task,
  x: 300,
  y: 200,
  label: "Process Data",
  description: "Processes incoming data",
  timeout: 5000,
  retries: 3
)

# Using builder pattern
graph =
  ExFlow.new()
  |> ExFlow.add_node!("task-1", :task, x: 0, y: 0)
  |> ExFlow.add_node!("task-2", :task, x: 200, y: 0)
```

### Creating Edges

```elixir
# Simple edge
{:ok, graph} = ExFlow.add_edge(graph, "edge-1", "task-1", "task-2")

# Edge with custom handles
{:ok, graph} = ExFlow.add_edge(graph, "edge-2", "decision-1", "task-3",
  source_handle: "yes",
  target_handle: "input"
)

# Edge with metadata
{:ok, graph} = ExFlow.add_edge(graph, "edge-3", "task-1", "task-2",
  label: "On Success",
  weight: 10
)
```

### Querying Graphs

```elixir
# Get all nodes
nodes = ExFlow.nodes(graph)

# Get specific node
{:ok, node} = ExFlow.get_node(graph, "task-1")

# Get all edges
edges = ExFlow.edges(graph)

# Count nodes and edges
node_count = length(ExFlow.nodes(graph))
edge_count = length(ExFlow.edges(graph))
```

### Storage Operations

```elixir
# Save workflow
:ok = ExFlow.save(graph, "my-workflow")

# Load workflow
{:ok, graph} = ExFlow.load("my-workflow")

# List all workflows
workflows = ExFlow.list()

# Delete workflow
:ok = ExFlow.delete("my-workflow")
```

## Testing Your Workflows

```elixir
defmodule MyApp.WorkflowsTest do
  use ExUnit.Case, async: true

  test "creates user onboarding workflow" do
    workflow = MyApp.Workflows.create_user_onboarding()
    
    # Verify structure
    nodes = ExFlow.nodes(workflow)
    assert length(nodes) == 5
    
    edges = ExFlow.edges(workflow)
    assert length(edges) == 4
    
    # Verify specific nodes exist
    assert {:ok, _} = ExFlow.get_node(workflow, "welcome")
    assert {:ok, _} = ExFlow.get_node(workflow, "send-email")
  end

  test "saves and loads workflow" do
    workflow = MyApp.Workflows.create_user_onboarding()
    
    # Save
    assert :ok = ExFlow.save(workflow, "test-workflow")
    
    # Load
    assert {:ok, loaded} = ExFlow.load("test-workflow")
    
    # Verify same structure
    assert length(ExFlow.nodes(loaded)) == length(ExFlow.nodes(workflow))
    
    # Cleanup
    ExFlow.delete("test-workflow")
  end
end
```

## Architecture

### Components

- **ExFlow** - Main API module (simplified interface)
- **ExFlow.Core.Graph** - Low-level graph operations
- **ExFlow.Storage** - Storage behaviour
- **ExFlow.Storage.InMemory** - In-memory storage adapter
- **ExFlow.Storage.Ecto** - Database storage adapter
- **ExFlow.Serializer** - Graph serialization/deserialization

### Data Flow

```
User Code
    ↓
ExFlow API (simplified)
    ↓
ExFlow.Core.Graph (core operations)
    ↓
LibGraph (underlying graph library)
    ↓
ExFlow.Storage (persistence)
```

## Best Practices

### 1. Use Meaningful IDs

```elixir
# Good
ExFlow.add_node!(graph, "validate-user-input", :task)

# Avoid
ExFlow.add_node!(graph, "node-1", :task)
```

### 2. Add Descriptive Metadata

```elixir
ExFlow.add_node!(graph, "process-payment", :task,
  label: "Process Payment",
  description: "Charges customer credit card",
  timeout: 30_000,
  retry_policy: "exponential_backoff"
)
```

### 3. Handle Errors Gracefully

```elixir
case ExFlow.add_node(graph, id, type) do
  {:ok, graph} -> graph
  {:error, :duplicate_id} -> 
    # Handle duplicate
    graph
  {:error, reason} -> 
    # Handle other errors
    raise "Failed: #{inspect(reason)}"
end
```

### 4. Use Builder Pattern for Complex Graphs

```elixir
graph =
  ExFlow.new()
  |> ExFlow.add_node!("start", :trigger)
  |> ExFlow.add_node!("step1", :task)
  |> ExFlow.add_node!("step2", :task)
  |> ExFlow.add_edge!("e1", "start", "step1")
  |> ExFlow.add_edge!("e2", "step1", "step2")
```

### 5. Version Your Workflows

```elixir
ExFlow.add_node!(graph, "process", :task,
  version: "2.0",
  schema_version: "v2",
  updated_at: DateTime.utc_now()
)
```

## Troubleshooting

### Database Connection Issues

```bash
# Check database is running
psql -U postgres -c "SELECT 1"

# Recreate database
mix ecto.drop
mix ecto.create
mix ecto.migrate
```

### Asset Build Issues

```bash
# Rebuild assets
cd assets
npm install
npm run build
```

### Storage Issues

```elixir
# Check storage configuration
Application.get_env(:ex_flow, :storage)

# List saved workflows
ExFlow.list()

# Test save/load
graph = ExFlow.new()
ExFlow.save(graph, "test")
{:ok, _} = ExFlow.load("test")
```

## Resources

- [ExFlow Documentation](../../docs/USAGE_GUIDE.md)
- [Quick Start Guide](../../docs/QUICK_START.md)
- [GitHub Repository](https://github.com/thanos/ExFlowGraph)

## License

MIT License - see LICENSE file for details
