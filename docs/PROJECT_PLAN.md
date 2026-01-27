# ExFlow: Detailed Project Plan
**Native LiveView Node Editor**

---

## Product Goal

Deliver a **high-performance, "native-feeling" node editor** for Phoenix LiveView where:

- **Nodes** render as **HTML `<div>`** elements (for crisp text/layout and easy DOM interaction)
- **Edges** render as **SVG `<path>`** elements (for smooth curves + fast redraw)
- **Dragging / zoom / pan** is **client-side only** via a dedicated hook (`ExFlowCanvas`) for *zero-latency* UX
- The backend canonical graph is **immutable** using **`libgraph`**
- Persistence is pluggable via a **behaviour-based storage adapter**

---

## Architecture Overview (Target State)

### 1) Data/Domain Layer (Elixir)

**Module boundary:** `ExFlow.Core.Graph`

**Backing structure:** `Graph` (`libgraph`)

**Vertex label format:** A single map label per node:
```elixir
%{
  id: "node-1",
  type: :agent | :task | :custom,
  position: %{x: 100, y: 200},
  metadata: %{...}
}
```

**Edge label/metadata:** Edge label = edge id; metadata includes handles + ids:
```elixir
%{
  id: "edge-1",
  source: "node-1",
  source_handle: "out",
  target: "node-2",
  target_handle: "in"
}
```

**Key functions:**
- `new/0` — create empty graph
- `add_node/3` — add vertex with typed metadata
- `add_edge/5` — add edge with handle info
- `update_node_position/3` — update position in metadata
- `delete_node/2`, `delete_edge/2` — removal operations

### 2) UI Layer (Phoenix Components + LiveView)

**`ExFlow.Canvas`** renders:
- SVG edge layer (z-index: 0)
- HTML node layer (z-index: 10)
- Attaches `phx-hook="ExFlowCanvas"` for client interaction

**`ExFlow.Node`** renders:
- Absolute-positioned `<div>` with `.exflow-node` class
- `data-id`, `data-x`, `data-y` attributes for hook coordination
- Handle elements with `data-handle` attributes

**`ExFlow.Edge`** renders:
- SVG `<path>` with initial SSR `d` attribute
- Computed by Elixir helper: `cubic_bezier_path/2`
- `data-edge-id`, `data-source-id`, `data-target-id` for client updates

### 3) Interaction Layer (JS Hook)

**`ExFlowCanvas` hook** (`assets/js/hooks/ex_flow.js`) handles:

**Drag Loop:**
1. `mousedown` on `.exflow-node` → capture start position
2. `mousemove` → apply `transform: translate(x, y)` to node element
3. Calculate cubic bezier path in JS and update connected `<path d>` attributes
4. `mouseup` → `pushEvent("update_position", {id, x, y})` to server

**Pan/Zoom (future):**
- Apply container-level transform matrix
- Keep node positions in world coordinates
- No server events during pan/zoom

**Key principles:**
- Zero server round-trips during drag
- Immediate visual feedback via DOM manipulation
- Single persistence event on mouseup

### 4) Persistence Layer (Behaviour Adapter)

**`ExFlow.Storage` behaviour:**
```elixir
@callback load(id :: String.t()) :: {:ok, Graph.t()} | {:error, term()}
@callback save(id :: String.t(), graph :: Graph.t()) :: :ok | {:error, term()}
```

**Implementations:**

**`ExFlow.Storage.InMemory`** (current):
- Agent-based in-memory store
- Suitable for dev/demo/testing

**Future adapters:**
- `ExFlow.Storage.Ecto` — database persistence with versioning
- `ExFlow.Storage.S3` — cloud object storage
- `ExFlow.Storage.File` — local filesystem

---

## Visual-First Delivery Sprints

### Sprint 1 — "Hybrid Canvas MVP" ✅ COMPLETED

**Visual Deliverable:**
- `/flow` route shows canvas with 2 nodes + 1 edge
- Drag nodes with zero-latency client-side updates
- On mouseup: server persists position and rerender stays stable

**Backfill Logic:**
- `ExFlow.Core.Graph` as canonical state
- `Storage.InMemory` adapter started under supervision tree
- LiveView event handler: `"update_position"`

**Idiomatic Elixir Patterns:**
- Functional graph transforms (return new graph, no mutation)
- Behaviour-driven boundary for persistence
- LiveView as "projection" of backend state
- Supervised Agent for in-memory storage

**Exit Criteria:**
- Can drag nodes smoothly
- Position persists across LiveView reconnects
- Edges redraw correctly during drag

---

### Sprint 2 — "Canvas UX: Pan/Zoom + Selection"

**Visual Deliverable:**
- Pan canvas by dragging background
- Zoom in/out with mouse wheel or pinch gesture
- Click node to select (highlight + sidebar showing metadata)
- Multi-select with Shift+click or marquee selection

**Backfill Logic:**
- Client-side transform matrix stored in hook state
- Server stores only semantic node position (world coords), not viewport
- Selected node IDs tracked in LiveView assigns

**Idiomatic Patterns:**
- Keep UI transforms out of assigns; only persist meaningful state
- Use `assign(socket, :selected_nodes, MapSet.new([id]))` for selection
- Emit selection events for external integrations

**Technical Details:**
- Transform matrix: `{scale, translateX, translateY}`
- Apply via CSS transform on container
- Convert mouse coords to world coords for hit testing
- Clamp zoom levels (min: 0.1, max: 3.0)

---

### Sprint 3 — "Graph Editing: Create/Delete + Connect Handles"

**Visual Deliverable:**
- Node palette with draggable node types
- Click palette item or canvas to add node
- Delete node via keyboard (Delete/Backspace) or context menu
- Drag from source handle to target handle to create edge
- Show temporary "ghost edge" during connection drag
- Validate handle compatibility (type checking)

**Backfill Logic:**
- `add_node/3` with generated UUID
- `add_edge/5` with handle validation
- `delete_node/2` cascades to connected edges
- Server validates handle compatibility rules

**Idiomatic Patterns:**
- Explicit command events: `"create_node"`, `"delete_node"`, `"create_edge"`
- Validate in Elixir; optimistic UI in JS then reconcile
- Use changesets for node/edge validation
- Broadcast graph changes via PubSub for multi-user

**Handle Validation:**
```elixir
defmodule ExFlow.HandleValidator do
  def compatible?(source_type, target_type) do
    # Define type compatibility matrix
  end
end
```

---

### Sprint 4 — "Performance & Scale"

**Visual Deliverable:**
- Demo with 200–1,000 nodes remains smooth
- Dragging + edge redraw stays at 60fps
- Lazy rendering for off-screen nodes
- Performance metrics overlay (optional dev mode)

**Backfill Logic:**
- Edge redraw throttling via `requestAnimationFrame`
- Spatial indexing for hit-tests (R-tree or grid)
- "Dirty edge set" — only update affected edges
- Virtual scrolling for node list (if applicable)

**Idiomatic Patterns:**
- LiveView updates only on semantic commits
- Client hook owns animation frame scheduling
- Use `phx-update="ignore"` for stable node containers
- Debounce expensive operations (layout, search)

**Optimization Techniques:**
- Cache node bounding boxes
- Use CSS `will-change` for dragged elements
- Batch DOM updates
- Consider Web Workers for heavy computation

---

### Sprint 5 — "Persistence + Collaboration Readiness"

**Visual Deliverable:**
- Save/load graphs by ID via UI controls
- "Last saved" timestamp indicator
- Auto-save with debouncing
- Conflict resolution UI for concurrent edits

**Backfill Logic:**
- Ecto storage adapter with schema:
  ```elixir
  schema "graphs" do
    field :name, :string
    field :data, :map  # JSON-serialized graph
    field :version, :integer
    timestamps()
  end
  ```
- Optimistic locking via version field
- PubSub broadcasts for real-time sync
- Operational Transform or CRDT for conflict resolution

**Idiomatic Patterns:**
- Behaviours for storage (already defined)
- Multi-tenancy via `graph_id` + policy checks
- Use `Phoenix.Tracker` for presence
- Implement `Phoenix.PubSub` topics per graph

**Collaboration Features:**
- Show cursors of other users
- Lock nodes being edited
- Merge strategies for conflicts

---

### Sprint 6 — "Extensibility: Node Types & Rendering Contracts"

**Visual Deliverable:**
- Different node types with custom UI (colors, icons, ports)
- Config-driven node schema (JSON/Elixir config)
- Plugin system for custom node renderers
- Node templates library

**Backfill Logic:**
- Typed node metadata with validation schemas
- Node renderer registry (Elixir side)
- Handle layout definitions (JS side)
- Protocol-based node capability system

**Idiomatic Patterns:**
- Use Elixir protocols for node type capabilities:
  ```elixir
  defprotocol ExFlow.NodeType do
    def render(node)
    def handles(node)
    def validate(node, data)
  end
  ```
- Data-first rendering (no ad-hoc special-casing)
- Component composition for complex nodes
- JSON Schema for node data validation

**Node Type Examples:**
- **Agent Node:** Multiple output handles, execution state
- **Task Node:** Input/output handles, progress indicator
- **Decision Node:** Conditional branching logic
- **Data Node:** Schema-validated data storage

---

## Technical Constraints & Design Decisions

### Why Hybrid Rendering (HTML Nodes + SVG Edges)?

**HTML Nodes:**
- Native text rendering (crisp, accessible)
- Easy DOM manipulation for drag
- Standard CSS styling and layout
- Form inputs work naturally

**SVG Edges:**
- Smooth curves with cubic bezier
- Hardware-accelerated rendering
- Efficient path updates
- Zoom-independent stroke width

### Why libgraph?

- **Immutable:** Functional updates, no hidden mutation
- **Battle-tested:** Used in production Elixir apps
- **Rich API:** Pathfinding, cycles, components
- **Serializable:** Easy to persist/restore

### Why Client-Side Drag?

- **Zero latency:** Immediate visual feedback
- **Reduced server load:** No events during drag
- **Smooth UX:** No network jitter
- **Offline capable:** Works during disconnects

### Why Behaviour-Based Storage?

- **Testability:** Mock adapters for tests
- **Flexibility:** Swap backends without changing logic
- **Separation:** Domain logic independent of persistence
- **Evolution:** Add features (versioning, encryption) per adapter

---

## Testing Strategy

### Unit Tests (Elixir)
- `ExFlow.Core.Graph` functions
- Storage adapter implementations
- Node/edge validation logic
- Handle compatibility rules

### Integration Tests (Elixir)
- LiveView event handlers
- Graph persistence round-trips
- PubSub broadcasting
- Multi-user scenarios

### E2E Tests (Wallaby/Playwright)
- Drag node and verify position
- Create edge via handles
- Pan/zoom interactions
- Save/load workflows

### Performance Tests
- Render 1000 nodes benchmark
- Drag latency measurements
- Memory profiling
- Edge update throughput

---

## Deployment Considerations

### Production Checklist
- [ ] Database migrations for Ecto adapter
- [ ] PubSub configured (Redis/Postgres)
- [ ] Asset compilation (esbuild + tailwind)
- [ ] WebSocket configuration (load balancer)
- [ ] Monitoring (Telemetry + metrics)
- [ ] Error tracking (Sentry/AppSignal)

### Scaling Strategies
- Horizontal: Multiple Phoenix nodes + PubSub
- Vertical: Optimize graph operations
- Caching: ETS for hot graphs
- CDN: Static assets + edge caching

### Security
- Authorization: Policy-based access control
- Validation: Server-side for all mutations
- Rate limiting: Prevent abuse
- XSS prevention: Sanitize user content

---

## Future Enhancements

### Phase 2 Features
- **Undo/Redo:** Command pattern with history stack
- **Copy/Paste:** Clipboard API integration
- **Grouping:** Visual containers for nodes
- **Minimap:** Overview + navigation widget
- **Search:** Full-text node/edge search
- **Export:** PNG/SVG/JSON export

### Phase 3 Features
- **Execution Engine:** Run workflows defined by graphs
- **Debugging:** Step-through execution
- **Templates:** Reusable graph patterns
- **Marketplace:** Share/discover node types
- **AI Assist:** Auto-layout, suggestions
- **Mobile:** Touch-optimized interface

---

## Success Metrics

### Performance
- Drag latency: < 16ms (60fps)
- Initial render: < 500ms for 100 nodes
- Memory: < 50MB for 1000 nodes

### Reliability
- Uptime: 99.9%
- Data loss: 0%
- Conflict resolution: 100% success

### Usability
- Time to first node: < 10 seconds
- Learning curve: < 5 minutes
- User satisfaction: > 4.5/5

---

## References

- [libgraph Documentation](https://hexdocs.pm/libgraph/)
- [Phoenix LiveView Hooks](https://hexdocs.pm/phoenix_live_view/js-interop.html#client-hooks)
- [SVG Path Specification](https://www.w3.org/TR/SVG/paths.html)
- [React Flow](https://reactflow.dev/) (inspiration)
- [Rete.js](https://rete.js.org/) (inspiration)

---

**Document Version:** 1.0  
**Last Updated:** January 26, 2026  
**Status:** Sprint 1 Complete, Sprint 2-6 Planned
