# ExFlow

A simple and powerful Elixir library for building flow-based graphs. Perfect for workflow engines, data pipelines, visual programming tools, and AI agent orchestration.



## Features

- **Simple API** - Intuitive functions for creating and manipulating graphs
- **Immutable** - Functional approach with immutable data structures
- **Persistent** - Multiple storage backends (in-memory, PostgreSQL)
- **Visual** - Includes Phoenix LiveView demo with drag-and-drop editor
- **Well-tested** - Comprehensive test suite with Mox for mocking
- **Documented** - Extensive documentation and examples

## Quick Start

### Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:ex_flow, "~> 0.1.0"}
  ]
end
```

### Basic Usage

```elixir
# Create a workflow
graph =
  ExFlow.new()
  |> ExFlow.add_node!("start", :trigger, x: 0, y: 0, label: "Start")
  |> ExFlow.add_node!("process", :task, x: 200, y: 0, label: "Process Data")
  |> ExFlow.add_node!("end", :output, x: 400, y: 0, label: "Complete")
  |> ExFlow.add_edge!("e1", "start", "process")
  |> ExFlow.add_edge!("e2", "process", "end")

# Save it
:ok = ExFlow.save(graph, "my-workflow")

# Load it back
{:ok, graph} = ExFlow.load("my-workflow")
```

## Documentation

- **[Quick Start Guide](docs/QUICK_START.md)** - Get started in 5 minutes
- **[Usage Guide](docs/USAGE_GUIDE.md)** - Comprehensive examples and patterns
- **[API Reference](https://hexdocs.pm/ex_flow)** - Complete API documentation
- **[Demo Application](demo/README.md)** - Full Phoenix LiveView example

## Repository Structure

This is a monorepo containing:

- **`lib/`** - ExFlow library source code
- **`test/`** - Library tests
- **`demo/`** - Phoenix LiveView demo application
- **`docs/`** - Documentation and guides

## Demo Application

The `demo` directory contains a complete Phoenix application showcasing ExFlow's capabilities:

<img width="600" alt="ExFlow Visual Editor" src="https://github.com/user-attachments/assets/eca96766-2ace-4b61-8380-ce745ab3ca0e" />

### Features

- Visual graph editor with drag-and-drop
- Real-time collaboration
- Undo/Redo support
- PostgreSQL persistence
- Pre-built example workflows

### Running the Demo

```bash
cd demo
mix setup
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000)

## Example Workflows

### Sequential Processing

```elixir
ExFlow.new()
|> ExFlow.add_node!("step1", :task, x: 0, y: 0, label: "Step 1")
|> ExFlow.add_node!("step2", :task, x: 200, y: 0, label: "Step 2")
|> ExFlow.add_node!("step3", :task, x: 400, y: 0, label: "Step 3")
|> ExFlow.add_edge!("e1", "step1", "step2")
|> ExFlow.add_edge!("e2", "step2", "step3")
```

### Conditional Branching

```elixir
ExFlow.new()
|> ExFlow.add_node!("start", :trigger, x: 0, y: 100)
|> ExFlow.add_node!("decision", :decision, x: 200, y: 100)
|> ExFlow.add_node!("path-a", :task, x: 400, y: 50)
|> ExFlow.add_node!("path-b", :task, x: 400, y: 150)
|> ExFlow.add_edge!("e1", "start", "decision")
|> ExFlow.add_edge!("e2", "decision", "path-a", source_handle: "yes")
|> ExFlow.add_edge!("e3", "decision", "path-b", source_handle: "no")
```

### Parallel Processing

```elixir
ExFlow.new()
|> ExFlow.add_node!("start", :trigger, x: 0, y: 100)
|> ExFlow.add_node!("worker1", :task, x: 200, y: 50)
|> ExFlow.add_node!("worker2", :task, x: 200, y: 100)
|> ExFlow.add_node!("worker3", :task, x: 200, y: 150)
|> ExFlow.add_node!("merge", :task, x: 400, y: 100)
|> ExFlow.add_edge!("e1", "start", "worker1")
|> ExFlow.add_edge!("e2", "start", "worker2")
|> ExFlow.add_edge!("e3", "start", "worker3")
|> ExFlow.add_edge!("e4", "worker1", "merge")
|> ExFlow.add_edge!("e5", "worker2", "merge")
|> ExFlow.add_edge!("e6", "worker3", "merge")
```

See [Usage Guide](docs/USAGE_GUIDE.md) for more examples including ETL pipelines, AI agents, and order processing workflows.

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

## Testing

```bash
# Run all tests
mix test

# Run with coverage
mix coveralls

# Run specific test file
mix test test/ex_flow/core/graph_test.exs
```


## License

MIT License - see [LICENSE](LICENSE) file for details.

## Resources


- [GitHub Issues](https://github.com/thanos/ExFlowGraph/issues)
- [Changelog](CHANGELOG.md)
- [Phoenix Framework](https://www.phoenixframework.org/)
