# Labels and Metadata in ExFlowGraph

ExFlowGraph now supports labels and metadata for both nodes and edges, allowing you to attach custom data and display names to your graph elements.

## Node Labels and Metadata

### Adding a Node with Label and Metadata

```elixir
{:ok, graph} =
  ExFlow.Core.Graph.add_node(graph, "node-id", :agent, %{
    position: %{x: 100, y: 100},
    label: "Data Processor",
    metadata: %{
      status: "active",
      priority: "high",
      assigned_to: "worker-1"
    }
  })
```

### Node Schema

```elixir
%{
  id: String.t(),              # Unique identifier
  type: atom(),                # Node type (e.g., :agent, :task)
  label: String.t() | nil,     # Optional display label
  position: %{x: number(), y: number()},
  metadata: map()              # Arbitrary metadata
}
```

## Edge Labels and Metadata

### Adding an Edge with Label and Metadata

```elixir
{:ok, graph} =
  ExFlow.Core.Graph.add_edge(
    graph,
    "edge-id",
    "source-node-id",
    "out",
    "target-node-id",
    "in",
    %{
      label: "data flow",
      metadata: %{
        bandwidth: "high",
        protocol: "streaming",
        rate_limit: 1000
      }
    }
  )
```

### Edge Schema

```elixir
%{
  id: String.t(),              # Unique identifier
  source: String.t(),          # Source node ID
  source_handle: String.t(),   # Source handle ("out")
  target: String.t(),          # Target node ID
  target_handle: String.t(),   # Target handle ("in")
  label: String.t() | nil,     # Optional display label
  metadata: map()              # Arbitrary metadata
}
```

## Using Commands

### CreateEdgeCommand with Metadata

```elixir
command = ExFlow.Commands.CreateEdgeCommand.new(
  edge_id,
  source_id,
  "out",
  target_id,
  "in",
  %{
    label: "my edge",
    metadata: %{custom_field: "value"}
  }
)

{:ok, history, graph} = ExFlow.HistoryManager.execute(history, command, graph)
```

## Display in UI

The demo automatically uses labels when displaying nodes:
- If a node has a label, it shows: `"Label · node-id"`
- If no label, it shows: `"Type · node-id"`

## Example: Complete Workflow

```elixir
# Create graph
graph = ExFlow.Core.Graph.new()

# Add nodes with labels and metadata
{:ok, graph} = ExFlow.Core.Graph.add_node(graph, "processor-1", :agent, %{
  position: %{x: 100, y: 100},
  label: "ML Processor",
  metadata: %{
    model: "gpt-4",
    temperature: 0.7,
    max_tokens: 1000
  }
})

{:ok, graph} = ExFlow.Core.Graph.add_node(graph, "validator-1", :task, %{
  position: %{x: 400, y: 100},
  label: "Data Validator",
  metadata: %{
    rules: ["required_fields", "type_checking"],
    strict_mode: true
  }
})

# Connect with labeled edge
{:ok, graph} = ExFlow.Core.Graph.add_edge(
  graph,
  "edge-1",
  "processor-1",
  "out",
  "validator-1",
  "in",
  %{
    label: "processed data",
    metadata: %{
      format: "json",
      compression: "gzip",
      encryption: true
    }
  }
)
```

## Accessing Metadata

```elixir
# Get nodes and access metadata
nodes = ExFlow.Core.Graph.get_nodes(graph)
for node <- nodes do
  IO.inspect(node.label, label: "Label")
  IO.inspect(node.metadata, label: "Metadata")
end

# Get edges and access metadata
edges = ExFlow.Core.Graph.get_edges(graph)
for edge <- edges do
  IO.inspect(edge.label, label: "Edge Label")
  IO.inspect(edge.metadata, label: "Edge Metadata")
end
```

## Notes

- Labels are optional (can be `nil`)
- Metadata is always a map (defaults to `%{}`)
- Metadata can contain any serializable Elixir term
- Labels are displayed in the UI, metadata is for programmatic use
- Use metadata for storing business logic data, configuration, or state
