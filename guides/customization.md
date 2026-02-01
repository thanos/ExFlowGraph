# Customization Guide

ExFlowGraph is designed to be highly customizable. This guide covers how to customize styling, create custom storage backends, and extend the library's functionality.

## Styling Customization

### Tailwind CSS Classes

ExFlowGraph uses Tailwind CSS classes that you can override or extend. The main classes are:

#### Canvas Container

```css
.exflow-container {
  /* Default styles applied to the canvas */
}
```

#### Nodes

```css
.exflow-node {
  /* Base node styling */
}

.exflow-node.selected {
  /* Selected node styling */
}
```

#### Handles

```css
.exflow-handle {
  /* Base handle styling */
}

.exflow-handle-source {
  /* Source handle (output) */
}

.exflow-handle-target {
  /* Target handle (input) */
}
```

#### Edges

```css
.exflow-edge {
  /* Edge path styling */
}
```

### Override Component Styles

You can pass custom classes through component attributes:

```heex
<ExFlowGraphWeb.ExFlow.Canvas.canvas
  id="my-canvas"
  class="my-custom-canvas-class"
  nodes={@nodes}
  edges={@edges}
  selected_node_ids={@selected_node_ids}
/>
```

### Custom Node Rendering

Create your own node component by copying and modifying the Node component:

```elixir
defmodule MyAppWeb.Components.CustomNode do
  use Phoenix.Component

  attr :id, :string, required: true
  attr :x, :integer, required: true
  attr :y, :integer, required: true
  attr :title, :string, default: ""
  attr :selected, :boolean, default: false
  attr :type, :atom, default: :default

  def node(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "exflow-node absolute select-none rounded-lg border px-3 py-2 text-sm cursor-grab active:cursor-grabbing pointer-events-auto transition-all",
        node_style_for_type(@type),
        if(@selected, do: "ring-4 ring-primary/30 border-primary border-2", else: "border-base-300 shadow-sm")
      ]}
      style={"left: #{@x}px; top: #{@y}px;"}
      data-node-id={@id}
    >
      <div class="font-medium"><%= @title %></div>

      <!-- Custom content based on type -->
      <%= if @type == :agent do %>
        <div class="mt-1 text-xs opacity-60">AI Agent</div>
      <% end %>

      <!-- Handles -->
      <span class="exflow-handle exflow-handle-source absolute right-0 top-1/2 inline-flex size-2 -translate-y-1/2 translate-x-1/2 rounded-full bg-primary"></span>
      <span class="exflow-handle exflow-handle-target absolute left-0 top-1/2 inline-flex size-2 -translate-x-1/2 -translate-y-1/2 rounded-full bg-base-content/40"></span>
    </div>
    """
  end

  defp node_style_for_type(:agent), do: "bg-blue-500/10 border-blue-500"
  defp node_style_for_type(:task), do: "bg-green-500/10 border-green-500"
  defp node_style_for_type(_), do: "bg-base-100/90"
end
```

### Custom Edge Styling

Modify edge appearance by customizing the Edge component:

```elixir
defmodule MyAppWeb.Components.CustomEdge do
  use Phoenix.Component

  attr :id, :string, required: true
  attr :source_x, :number, required: true
  attr :source_y, :number, required: true
  attr :target_x, :number, required: true
  attr :target_y, :number, required: true
  attr :selected, :boolean, default: false
  attr :animated, :boolean, default: false

  def edge(assigns) do
    ~H"""
    <g>
      <!-- Hit area -->
      <path
        class="exflow-edge"
        fill="none"
        stroke="transparent"
        stroke-width="20"
        d={path({@source_x, @source_y}, {@target_x, @target_y})}
        data-edge-id={@id}
        style="cursor: pointer;"
      />

      <!-- Visible path -->
      <path
        id={"exflow-edge-#{@id}"}
        fill="none"
        stroke-width={if(@selected, do: "4", else: "2")}
        d={path({@source_x, @source_y}, {@target_x, @target_y})}
        class={[
          "transition-all duration-200",
          if(@selected, do: "stroke-primary", else: "stroke-base-content/50 hover:stroke-base-content/80"),
          if(@animated, do: "animate-pulse", else: "")
        ]}
        style="pointer-events: none;"
      />

      <!-- Optional arrow marker -->
      <polygon
        points="0,-4 8,0 0,4"
        fill="currentColor"
        transform={arrow_transform(@target_x, @target_y, @source_x, @source_y)}
        class={if(@selected, do: "text-primary", else: "text-base-content/50")}
      />
    </g>
    """
  end

  defp path({x1, y1}, {x2, y2}) do
    # Cubic Bezier curve
    dx = x2 - x1
    cx1 = x1 + dx * 0.5
    cx2 = x2 - dx * 0.5
    "M #{x1},#{y1} C #{cx1},#{y1} #{cx2},#{y2} #{x2},#{y2}"
  end

  defp arrow_transform(x, y, source_x, _source_y) do
    rotation = if x < source_x, do: 180, else: 0
    "translate(#{x}, #{y}) rotate(#{rotation})"
  end
end
```

## Custom Storage Backends

ExFlowGraph includes an InMemory storage backend. You can create custom backends for databases or external storage.

### Storage Protocol

Implement the `ExFlow.Storage` behaviour:

```elixir
defmodule MyApp.Storage.Database do
  @behaviour ExFlow.Storage

  alias MyApp.Repo
  alias MyApp.Schema.GraphState
  alias ExFlow.Core.Graph

  @impl ExFlow.Storage
  def save(id, graph) do
    # Serialize graph to JSON
    serialized = Graph.serialize(graph)

    attrs = %{
      storage_id: id,
      data: serialized,
      updated_at: DateTime.utc_now()
    }

    case Repo.get_by(GraphState, storage_id: id) do
      nil ->
        %GraphState{}
        |> GraphState.changeset(attrs)
        |> Repo.insert()

      state ->
        state
        |> GraphState.changeset(attrs)
        |> Repo.update()
    end

    :ok
  end

  @impl ExFlow.Storage
  def load(id) do
    case Repo.get_by(GraphState, storage_id: id) do
      nil ->
        {:error, :not_found}

      state ->
        case Graph.deserialize(state.data) do
          {:ok, graph} -> {:ok, graph}
          error -> error
        end
    end
  end

  @impl ExFlow.Storage
  def delete(id) do
    case Repo.get_by(GraphState, storage_id: id) do
      nil -> {:error, :not_found}
      state -> Repo.delete(state)
    end

    :ok
  end

  @impl ExFlow.Storage
  def list do
    GraphState
    |> Repo.all()
    |> Enum.map(& &1.storage_id)
  end
end
```

### Using Custom Storage

Replace `InMemory` with your custom storage:

```elixir
# Instead of:
InMemory.save(@storage_id, graph)

# Use:
MyApp.Storage.Database.save(@storage_id, graph)
```

## Custom Node Types

Define custom node types with specific behaviors:

```elixir
defmodule MyApp.NodeTypes do
  @type node_type :: :agent | :task | :trigger | :condition | :action

  def node_type_config(:agent) do
    %{
      label: "AI Agent",
      icon: "agent",
      color: "blue",
      inputs: [:data, :config],
      outputs: [:result, :error],
      default_metadata: %{
        model: "gpt-4",
        temperature: 0.7
      }
    }
  end

  def node_type_config(:trigger) do
    %{
      label: "Trigger",
      icon: "trigger",
      color: "yellow",
      inputs: [],
      outputs: [:event],
      default_metadata: %{
        event_type: "webhook"
      }
    }
  end

  def node_type_config(:condition) do
    %{
      label: "Condition",
      icon: "condition",
      color: "purple",
      inputs: [:data],
      outputs: [:true, :false],
      default_metadata: %{
        condition: "value > 10"
      }
    }
  end

  def all_types do
    [:agent, :task, :trigger, :condition, :action]
  end
end
```

Use these types when creating nodes:

```elixir
def handle_event("add_node", %{"type" => type_string}, socket) do
  type = String.to_existing_atom(type_string)
  config = MyApp.NodeTypes.node_type_config(type)

  command = ExFlow.Commands.CreateNodeCommand.new(
    "node-#{System.unique_integer([:positive])}",
    type,
    Map.merge(config.default_metadata, %{
      position: %{x: 100, y: 100},
      label: config.label
    })
  )

  # Execute command...
end
```

## JavaScript Hook Customization

Extend the JavaScript hook to add custom behaviors:

```javascript
// assets/js/hooks/custom_ex_flow.js
import ExFlowCanvas from "../../deps/ex_flow_graph/assets/js/hooks/ex_flow"

const CustomExFlowCanvas = {
  ...ExFlowCanvas,

  mounted() {
    // Call original mounted
    ExFlowCanvas.mounted.call(this)

    // Add custom behavior
    this.el.addEventListener('dblclick', (e) => {
      const nodeEl = e.target.closest('.exflow-node')
      if (nodeEl) {
        const nodeId = nodeEl.dataset.nodeId
        this.pushEvent("double_click_node", { id: nodeId })
      }
    })
  },

  // Override drag behavior
  handleMouseMove(e) {
    if (this.dragState.type === 'node') {
      // Custom drag behavior
      const dx = e.clientX - this.dragState.startX
      const dy = e.clientY - this.dragState.startY

      // Snap to grid
      const gridSize = 20
      const snappedX = Math.round((this.dragState.originalX + dx) / gridSize) * gridSize
      const snappedY = Math.round((this.dragState.originalY + dy) / gridSize) * gridSize

      this.dragState.element.style.left = `${snappedX}px`
      this.dragState.element.style.top = `${snappedY}px`

      return
    }

    // Call original for other cases
    ExFlowCanvas.handleMouseMove.call(this, e)
  }
}

export default CustomExFlowCanvas
```

Register your custom hook:

```javascript
// app.js
import CustomExFlowCanvas from "./hooks/custom_ex_flow"

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: {ExFlowCanvas: CustomExFlowCanvas}
})
```

## Advanced Configuration

### Canvas Options

Configure canvas behavior through assigns:

```elixir
def mount(_params, _session, socket) do
  socket =
    socket
    |> assign(:graph, graph)
    |> assign(:canvas_config, %{
      grid_size: 20,
      snap_to_grid: true,
      allow_pan: true,
      allow_zoom: true,
      max_zoom: 2.0,
      min_zoom: 0.5
    })

  {:ok, socket}
end
```

### Validation Rules

Add validation for graph operations:

```elixir
defmodule MyApp.GraphValidator do
  def validate_edge_creation(graph, source_id, target_id) do
    cond do
      would_create_cycle?(graph, source_id, target_id) ->
        {:error, "Cannot create edge: would create cycle"}

      exceeds_max_edges?(graph) ->
        {:error, "Maximum number of edges reached"}

      true ->
        :ok
    end
  end

  defp would_create_cycle?(graph, source_id, target_id) do
    # Implement cycle detection
    # Use libgraph's path functions
    case LibGraph.path(graph, target_id, source_id) do
      nil -> false
      _path -> true
    end
  end

  defp exceeds_max_edges?(graph) do
    length(ExFlow.Core.Graph.get_edges(graph)) >= 100
  end
end
```

Use validation in event handlers:

```elixir
def handle_event("create_edge", params, socket) do
  %{
    "source_id" => source_id,
    "target_id" => target_id
  } = params

  case MyApp.GraphValidator.validate_edge_creation(
    socket.assigns.graph,
    source_id,
    target_id
  ) do
    :ok ->
      # Create edge...

    {:error, reason} ->
      {:noreply, put_flash(socket, :error, reason)}
  end
end
```

## Multi-Handle Nodes

Create nodes with multiple input/output handles:

```elixir
defmodule MyAppWeb.Components.MultiHandleNode do
  use Phoenix.Component

  attr :id, :string, required: true
  attr :x, :integer, required: true
  attr :y, :integer, required: true
  attr :title, :string, default: ""
  attr :inputs, :list, default: ["in"]
  attr :outputs, :list, default: ["out"]

  def node(assigns) do
    ~H"""
    <div
      id={@id}
      class="exflow-node absolute"
      style={"left: #{@x}px; top: #{@y}px;"}
      data-node-id={@id}
    >
      <%= @title %>

      <!-- Left side - inputs -->
      <div class="absolute left-0 top-0 h-full flex flex-col justify-around">
        <%= for {handle, index} <- Enum.with_index(@inputs) do %>
          <span
            class="exflow-handle exflow-handle-target"
            data-handle={handle}
            style={"top: #{handle_position(index, length(@inputs))}%"}
            title={handle}
          ></span>
        <% end %>
      </div>

      <!-- Right side - outputs -->
      <div class="absolute right-0 top-0 h-full flex flex-col justify-around">
        <%= for {handle, index} <- Enum.with_index(@outputs) do %>
          <span
            class="exflow-handle exflow-handle-source"
            data-handle={handle}
            style={"top: #{handle_position(index, length(@outputs))}%"}
            title={handle}
          ></span>
        <% end %>
      </div>
    </div>
    """
  end

  defp handle_position(index, total) do
    (index + 1) * (100 / (total + 1))
  end
end
```

## Performance Optimization

### Virtual Rendering

For large graphs, implement virtual rendering to only render visible nodes:

```elixir
def nodes_for_ui(graph, viewport) do
  graph
  |> ExFlow.Core.Graph.get_nodes()
  |> Enum.filter(&node_in_viewport?(&1, viewport))
  |> Enum.map(&format_node_for_ui/1)
end

defp node_in_viewport?(node, viewport) do
  node.position.x >= viewport.x - 100 and
  node.position.x <= viewport.x + viewport.width + 100 and
  node.position.y >= viewport.y - 100 and
  node.position.y <= viewport.y + viewport.height + 100
end
```

### Debouncing Updates

Debounce frequent updates to reduce server load:

```javascript
// In your custom hook
handleMouseMove(e) {
  if (this.dragState.type === 'node') {
    // Update UI immediately
    this.updateNodePosition(e)

    // Debounce server updates
    clearTimeout(this.updateTimer)
    this.updateTimer = setTimeout(() => {
      this.pushEvent("update_position", {
        id: this.dragState.nodeId,
        x: this.dragState.currentX,
        y: this.dragState.currentY
      })
    }, 100)
  }
}
```

## Best Practices

1. **Keep node components pure** - Avoid side effects in render functions
2. **Use metadata for custom data** - Don't modify the core graph structure
3. **Implement proper validation** - Validate operations before executing
4. **Test custom commands** - Ensure undo/redo works correctly
5. **Document custom types** - Make your node types discoverable
6. **Consider performance** - Large graphs may need optimization
7. **Follow Tailwind patterns** - Use consistent styling approaches
8. **Version your storage** - Add version fields for future migrations

## Examples

Check the demo application for complete examples of:

- Custom styling with DaisyUI theme
- InMemory storage implementation
- Multiple node types (agent, task)
- Custom event handlers
- Keyboard shortcuts
- Modal forms
- And much more!

```bash
cd demo
mix phx.server
# Explore the code in demo/lib/demo_web/live/home_live.ex
```
