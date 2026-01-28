# ExFlow Quick Start Guide

Get started with ExFlow in 5 minutes!

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:ex_flow, "~> 0.1.0"}
  ]
end
```

Run:

```bash
mix deps.get
```

## Your First Graph

### 1. Create a Simple Workflow

```elixir
# Start IEx
iex -S mix

# Create a new graph
graph = ExFlow.new()

# Add nodes
{:ok, graph} = ExFlow.add_node(graph, "start", :trigger, x: 0, y: 0, label: "Start")
{:ok, graph} = ExFlow.add_node(graph, "process", :task, x: 200, y: 0, label: "Process")
{:ok, graph} = ExFlow.add_node(graph, "end", :output, x: 400, y: 0, label: "End")

# Connect nodes
{:ok, graph} = ExFlow.add_edge(graph, "e1", "start", "process")
{:ok, graph} = ExFlow.add_edge(graph, "e2", "process", "end")

# View your graph
IO.inspect(ExFlow.nodes(graph))
IO.inspect(ExFlow.edges(graph))
```

### 2. Use the Builder Pattern

```elixir
graph =
  ExFlow.new()
  |> ExFlow.add_node!("start", :trigger, x: 0, y: 0, label: "Start")
  |> ExFlow.add_node!("process", :task, x: 200, y: 0, label: "Process")
  |> ExFlow.add_node!("end", :output, x: 400, y: 0, label: "End")
  |> ExFlow.add_edge!("e1", "start", "process")
  |> ExFlow.add_edge!("e2", "process", "end")
```

### 3. Save and Load

```elixir
# Save your graph
:ok = ExFlow.save(graph, "my-workflow")

# Load it back
{:ok, loaded_graph} = ExFlow.load("my-workflow")

# List all saved graphs
ExFlow.list()
```

## Common Patterns

### Sequential Workflow

```elixir
ExFlow.new()
|> ExFlow.add_node!("step1", :task, x: 0, y: 0, label: "Step 1")
|> ExFlow.add_node!("step2", :task, x: 200, y: 0, label: "Step 2")
|> ExFlow.add_node!("step3", :task, x: 400, y: 0, label: "Step 3")
|> ExFlow.add_edge!("e1", "step1", "step2")
|> ExFlow.add_edge!("e2", "step2", "step3")
```

### Branching Workflow

```elixir
ExFlow.new()
|> ExFlow.add_node!("start", :trigger, x: 0, y: 100)
|> ExFlow.add_node!("decision", :decision, x: 200, y: 100, label: "Check")
|> ExFlow.add_node!("path-a", :task, x: 400, y: 50, label: "Path A")
|> ExFlow.add_node!("path-b", :task, x: 400, y: 150, label: "Path B")
|> ExFlow.add_edge!("e1", "start", "decision")
|> ExFlow.add_edge!("e2", "decision", "path-a", source_handle: "yes")
|> ExFlow.add_edge!("e3", "decision", "path-b", source_handle: "no")
```

### Parallel Processing

```elixir
ExFlow.new()
|> ExFlow.add_node!("start", :trigger, x: 0, y: 100)
|> ExFlow.add_node!("worker1", :task, x: 200, y: 50, label: "Worker 1")
|> ExFlow.add_node!("worker2", :task, x: 200, y: 100, label: "Worker 2")
|> ExFlow.add_node!("worker3", :task, x: 200, y: 150, label: "Worker 3")
|> ExFlow.add_node!("merge", :task, x: 400, y: 100, label: "Merge")
|> ExFlow.add_edge!("e1", "start", "worker1")
|> ExFlow.add_edge!("e2", "start", "worker2")
|> ExFlow.add_edge!("e3", "start", "worker3")
|> ExFlow.add_edge!("e4", "worker1", "merge")
|> ExFlow.add_edge!("e5", "worker2", "merge")
|> ExFlow.add_edge!("e6", "worker3", "merge")
```

## Configuration

### In-Memory Storage (Development)

```elixir
# config/dev.exs
config :ex_flow, :storage, ExFlow.Storage.InMemory
```

### Database Storage (Production)

```elixir
# config/prod.exs
config :ex_flow, :storage, ExFlow.Storage.Ecto
config :ex_flow, :repo, MyApp.Repo
```

## Next Steps

1. Read the [Usage Guide](./USAGE_GUIDE.md) for detailed examples
2. Check out the [Demo Application](../demo) for a complete Phoenix LiveView example
3. Explore the [API Reference](https://hexdocs.pm/ex_flow) for all available functions

## Common Questions

**Q: How do I add custom metadata to nodes?**

```elixir
{:ok, graph} = ExFlow.add_node(graph, "task-1", :task,
  x: 100,
  y: 200,
  label: "My Task",
  description: "Does something important",
  timeout: 5000,
  retries: 3,
  custom_field: "custom_value"
)
```

**Q: How do I handle errors?**

```elixir
case ExFlow.add_node(graph, "task-1", :task) do
  {:ok, graph} -> 
    # Success
    graph
  {:error, reason} -> 
    # Handle error
    IO.puts("Error: #{inspect(reason)}")
    graph
end
```

**Q: Can I use custom node types?**

Yes! Node types are just atoms. Use any atom you want:

```elixir
{:ok, graph} = ExFlow.add_node(graph, "my-node", :my_custom_type)
```

**Q: How do I visualize my graphs?**

Check out the demo application which includes a Phoenix LiveView-based visual editor!

## Help & Support

- [GitHub Issues](https://github.com/your-repo/ExFlowGraph/issues)
- [Documentation](https://hexdocs.pm/ex_flow)
- [Examples](../demo)
