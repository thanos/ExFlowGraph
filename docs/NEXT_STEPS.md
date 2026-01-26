# ExFlow: Next Steps (Action Sets)

This document breaks down the remaining work into concrete, sequenced action sets. Each set includes:
- **Title** — What you're building
- **Rationale** — Why this matters now
- **Effort** — Estimated time (S/M/L/XL)
- **Priority** — P0 (critical) → P3 (nice-to-have)
- **Windsurf Best-Practices Prompt** — Copy-paste this to your LLM

---

## Set 1 — Stabilize Build + Test + Precommit

### Title
**Fix Failing Tests & Ensure Clean CI**

### Rationale
You need a clean baseline so every subsequent sprint is safe to iterate on. Currently `mix precommit` fails due to a missing `ExFlowGraph.hello/0` function that the generated test expects. This blocks all future work.

### Effort
**S (0.5–2 hours)**

### Priority
**P0 (Critical)**

### Current Status
- Test expects `ExFlowGraph.hello/0` to return `:world`
- Function was added but still fails (possible stale BEAM cache)
- Need to investigate and fix root cause

### Windsurf Best-Practices Prompt
```text
You are a senior Phoenix/Elixir maintainer. Make the minimum necessary edits to get `mix precommit` passing.

Constraints:
- Do not add/remove comments unnecessarily
- Prefer fixing root causes over disabling tests
- Keep changes small and localized
- If the issue is a stale build artifact, clean and recompile

Steps:
1. Run `mix clean` to clear stale artifacts
2. Run `mix compile --force` to rebuild everything
3. Run `mix test` to verify tests pass
4. Run `mix precommit` to ensure full CI passes

Provide a short summary of what failed and why, then implement the fix.
```

### Acceptance Criteria
- [ ] `mix test` passes with 0 failures
- [ ] `mix precommit` completes successfully
- [ ] No compiler warnings

---

## Set 2 — Canonical Graph Contract + Serialization

### Title
**Define Stable Graph Schema & Serialization**

### Rationale
As soon as you add creation/deletion/edges, you'll want a stable internal schema and persistence format. This prevents breaking changes later and enables smooth adapter swaps.

### Effort
**M (0.5–1.5 days)**

### Priority
**P0 (Critical)**

### Technical Requirements
- Define `ExFlow.Node` and `ExFlow.Edge` structs with validation
- Add `to_map/1` and `from_map/1` for serialization
- Ensure libgraph wrapper preserves invariants
- Add unit tests for all graph operations

### Windsurf Best-Practices Prompt
```text
Implement a stable internal graph contract for ExFlow using libgraph.

Requirements:
1. Define Node/Edge map schemas with clear field contracts:
   - Node: %{id, type, position: %{x, y}, metadata}
   - Edge: %{id, source, source_handle, target, target_handle}

2. Add serialization helpers suitable for persistence adapters:
   - ExFlow.Core.Graph.to_map(graph) -> map
   - ExFlow.Core.Graph.from_map(map) -> graph

3. Add validation functions:
   - validate_node/1 -> :ok | {:error, reason}
   - validate_edge/1 -> :ok | {:error, reason}

4. Add small unit tests for:
   - Graph creation and node/edge addition
   - Position updates
   - Serialization round-trips
   - Invalid data rejection

Keep code idiomatic and functional; no server roundtrips for dragging.
Use typespecs for all public functions.
```

### Acceptance Criteria
- [ ] All graph operations have tests
- [ ] Serialization round-trips preserve data
- [ ] Invalid data is rejected with clear errors
- [ ] Documentation includes examples

---

## Set 3 — Pan/Zoom in ExFlowCanvas Hook

### Title
**Add Zero-Latency Pan & Zoom to Canvas**

### Rationale
Pan/zoom is essential for "native editor" feel and working with large graphs. Without it, users are limited to tiny graphs that fit on screen.

### Effort
**M (1–2 days)**

### Priority
**P0 (Critical)**

### Technical Requirements
- Implement pan via drag on canvas background
- Implement zoom via mouse wheel (with pinch gesture support)
- Apply transform matrix to container element
- Convert mouse coordinates to world coordinates
- Clamp zoom levels (0.1x to 3.0x)

### Windsurf Best-Practices Prompt
```text
Extend the ExFlowCanvas LiveView hook to support pan/zoom with zero-latency.

Constraints:
- No server events during pan/zoom operations
- Node positions remain in world coordinates
- Apply pan/zoom via a container transform matrix
- Use requestAnimationFrame where needed to avoid layout thrash

Implementation details:
1. Add state to hook: {scale: 1.0, translateX: 0, translateY: 0}

2. Pan implementation:
   - Listen for mousedown on canvas background (not on nodes)
   - Track drag delta and update translateX/translateY
   - Apply via CSS transform on container

3. Zoom implementation:
   - Listen for wheel events
   - Calculate zoom delta (with modifier key support)
   - Zoom toward mouse cursor position
   - Clamp scale between 0.1 and 3.0

4. Coordinate conversion:
   - screenToWorld(x, y) -> {worldX, worldY}
   - worldToScreen(x, y) -> {screenX, screenY}

5. Edge case handling:
   - Prevent pan during node drag
   - Preserve zoom center on window resize
   - Reset view button (optional)

Provide clear separation between drag-node logic and pan/zoom logic.
Add comments explaining transform math.
```

### Acceptance Criteria
- [ ] Can pan by dragging background
- [ ] Can zoom with mouse wheel
- [ ] Zoom centers on cursor position
- [ ] Node dragging still works correctly
- [ ] Edges update during pan/zoom

---

## Set 4 — Edge Creation via Handles (Drag-to-Connect)

### Title
**Implement Drag-to-Connect Edge Creation**

### Rationale
Without edge creation, ExFlow is a viewer, not an editor. This is the core interaction that makes it useful.

### Effort
**L (2–4 days)**

### Priority
**P1 (High)**

### Technical Requirements
- Detect drag start from handle element
- Show temporary "ghost edge" during drag
- Highlight compatible target handles on hover
- Validate handle compatibility
- Push single event to server on drop
- Server validates and persists edge

### Windsurf Best-Practices Prompt
```text
Implement drag-to-connect edges between node handles in ExFlow.

Requirements:
1. Handle identification:
   - Handles have class `.exflow-handle`
   - Data attributes: data-handle="in|out", data-node-id="..."
   - Source handles: `.exflow-handle-source`
   - Target handles: `.exflow-handle-target`

2. Drag interaction:
   - mousedown on source handle starts edge creation
   - Show temporary SVG path following cursor
   - Calculate path from handle center to cursor
   - Highlight compatible target handles on hover

3. Drop validation:
   - Check if dropped on valid target handle
   - Validate handle compatibility (source->target)
   - Show error feedback for invalid connections

4. Server communication:
   - On valid drop: pushEvent("create_edge", {
       source_id, source_handle,
       target_id, target_handle
     })
   - Server validates and returns new edge or error
   - Reconcile UI with server response

5. Edge cases:
   - Can't connect node to itself (optional constraint)
   - Can't create duplicate edges
   - Handle type compatibility checking
   - Cancel on Escape key

Keep rendering hybrid: HTML nodes, SVG paths for edges.
Use cubic bezier for ghost edge path.
Add visual feedback (colors, animations) for states.
```

### Acceptance Criteria
- [ ] Can drag from source handle
- [ ] Ghost edge follows cursor
- [ ] Can drop on target handle
- [ ] Invalid drops show error
- [ ] Edge appears after successful creation
- [ ] Server validates all edges

---

## Set 5 — Storage Adapter Expansion (Ecto Adapter)

### Title
**Add Database Persistence with Ecto Adapter**

### Rationale
In-memory storage is great for demos, but database persistence unlocks real usage, multi-user collaboration, and production deployment.

### Effort
**L (2–5 days)**

### Priority
**P1 (High)**

### Technical Requirements
- Create Ecto schema for graphs
- Implement `ExFlow.Storage.Ecto` adapter
- Add migrations
- Support versioning/optimistic locking
- Add tests for persistence layer

### Windsurf Best-Practices Prompt
```text
Add an Ecto-backed ExFlow.Storage adapter for database persistence.

Requirements:
1. Create Ecto schema:
   ```elixir
   defmodule ExFlow.Graph do
     use Ecto.Schema
     
     schema "graphs" do
       field :name, :string
       field :data, :map  # JSON-serialized graph
       field :version, :integer, default: 1
       field :user_id, :id  # optional: multi-tenancy
       timestamps()
     end
   end
   ```

2. Create migration:
   - Add graphs table
   - Add indexes on name, user_id
   - Add unique constraint on name per user

3. Implement ExFlow.Storage.Ecto:
   - load(id) -> deserialize data field to Graph
   - save(id, graph) -> serialize and upsert with version check
   - Handle optimistic locking conflicts
   - Return clear error tuples

4. Add tests:
   - Save and load round-trip
   - Concurrent update conflict detection
   - Invalid data rejection
   - Query performance with large graphs

5. Configuration:
   - Make adapter configurable via application env
   - Support multiple storage backends simultaneously

Do not change the behaviour contract; keep adapter swap-friendly.
Use Ecto changesets for validation.
Add database indexes for performance.
```

### Acceptance Criteria
- [ ] Migration runs successfully
- [ ] Can save graph to database
- [ ] Can load graph from database
- [ ] Concurrent updates handled correctly
- [ ] Tests cover all scenarios
- [ ] Documentation includes setup instructions

---

## Set 6 — Performance Pass (Large Graphs)

### Title
**Optimize for 200-1000 Node Graphs**

### Rationale
Node editors fail if they don't stay smooth at scale. Performance must be designed, not patched. Users will quickly hit limits with real workflows.

### Effort
**L (3–7 days)**

### Priority
**P1 (High)**

### Technical Requirements
- Profile current performance
- Implement edge update optimization
- Add spatial indexing for hit tests
- Optimize rendering pipeline
- Add performance monitoring

### Windsurf Best-Practices Prompt
```text
Profile and optimize ExFlow for large graphs (200-1000 nodes).

Constraints:
- Dragging remains client-side and smooth (60fps)
- Only recompute/update edges impacted by the dragged node
- Avoid forced reflow; prefer cached geometry and rAF updates
- Maintain code clarity; don't sacrifice maintainability

Optimization strategy:
1. Profile current performance:
   - Create test graph with 500 nodes
   - Measure drag latency with Chrome DevTools
   - Identify bottlenecks (layout thrash, DOM updates, etc.)

2. Edge update optimization:
   - Build adjacency map: node_id -> [connected_edge_ids]
   - On drag, only update edges in adjacency list
   - Batch path updates in single rAF callback

3. Spatial indexing:
   - Implement simple grid-based spatial hash
   - Use for hit testing (which node is under cursor?)
   - Update grid incrementally during drag

4. Rendering optimizations:
   - Use CSS `will-change: transform` on dragged node
   - Cache node bounding boxes
   - Use `phx-update="ignore"` for stable containers
   - Consider virtual scrolling for off-screen nodes

5. Memory optimization:
   - Avoid creating new objects in hot paths
   - Reuse path string builders
   - Profile memory usage with heap snapshots

6. Add performance monitoring:
   - Track frame times during drag
   - Log slow operations (>16ms)
   - Add optional perf overlay for debugging

Provide a short perf report with before/after metrics.
Implement targeted improvements with clear comments.
Add performance tests to prevent regressions.
```

### Acceptance Criteria
- [ ] 500 node graph renders in < 1 second
- [ ] Dragging maintains 60fps
- [ ] Memory usage stays reasonable
- [ ] Performance tests added
- [ ] Documentation includes benchmarks

---

## Set 7 — Node Creation & Deletion UI

### Title
**Add Node Palette & Deletion Controls**

### Rationale
Users need to build graphs from scratch. This completes the core editing loop: create, connect, move, delete.

### Effort
**M (1–3 days)**

### Priority
**P1 (High)**

### Technical Requirements
- Node palette component
- Drag-to-create interaction
- Delete via keyboard or context menu
- Undo/redo foundation (optional)

### Windsurf Best-Practices Prompt
```text
Implement node creation and deletion UI for ExFlow.

Requirements:
1. Node Palette:
   - Sidebar or floating panel with available node types
   - Each type shows icon, name, description
   - Drag node type onto canvas to create
   - Alternative: click palette then click canvas

2. Node creation flow:
   - Generate unique ID (UUID)
   - Place at cursor position or canvas center
   - Push "create_node" event to server
   - Server validates and returns new node
   - Optimistic UI: show immediately, reconcile on response

3. Node deletion:
   - Select node(s) and press Delete/Backspace
   - Right-click context menu with "Delete" option
   - Confirm deletion if node has connections (optional)
   - Push "delete_node" event to server
   - Cascade delete connected edges

4. Multi-select (optional):
   - Shift+click to add to selection
   - Cmd/Ctrl+A to select all
   - Marquee selection by dragging background
   - Delete all selected nodes

5. Validation:
   - Server validates node type exists
   - Server checks permissions (if applicable)
   - Return clear error messages

Keep UI responsive with optimistic updates.
Add keyboard shortcuts documentation.
Consider accessibility (focus management, ARIA labels).
```

### Acceptance Criteria
- [ ] Can create nodes from palette
- [ ] Can delete nodes with keyboard
- [ ] Edges are deleted with nodes
- [ ] Optimistic UI feels instant
- [ ] Server validates all operations

---

## Set 8 — Selection & Multi-Select

### Title
**Implement Node Selection & Multi-Select**

### Rationale
Selection is fundamental for editing operations (delete, copy, group, etc.). Multi-select enables bulk operations.

### Effort
**M (1–2 days)**

### Priority
**P2 (Medium)**

### Technical Requirements
- Single node selection
- Multi-select with Shift/Cmd
- Marquee selection
- Selection state in LiveView
- Visual feedback

### Windsurf Best-Practices Prompt
```text
Implement node selection and multi-select in ExFlow.

Requirements:
1. Single selection:
   - Click node to select (deselects others)
   - Visual feedback: border highlight or glow
   - Store selected_ids in LiveView assigns
   - Show selection info in sidebar

2. Multi-select:
   - Shift+click to toggle selection
   - Cmd/Ctrl+click to add to selection
   - Cmd/Ctrl+A to select all
   - Click background to deselect all

3. Marquee selection:
   - Drag on background to create selection rectangle
   - Show semi-transparent selection box
   - Select all nodes intersecting rectangle
   - Works with modifier keys (add/remove from selection)

4. Selection state:
   - Track in LiveView: assign(:selected_node_ids, MapSet.new())
   - Sync to client via assigns
   - Client hook manages visual state
   - Server handles selection-based operations

5. Keyboard shortcuts:
   - Escape: clear selection
   - Delete: delete selected nodes
   - Cmd/Ctrl+C: copy (future)
   - Cmd/Ctrl+V: paste (future)

Keep selection state synchronized between client and server.
Add visual feedback for all selection states.
Consider accessibility (keyboard-only selection).
```

### Acceptance Criteria
- [ ] Can select single node
- [ ] Can multi-select with modifiers
- [ ] Marquee selection works
- [ ] Selection state persists
- [ ] Visual feedback is clear

---

## Set 9 — Undo/Redo System

### Title
**Implement Command Pattern for Undo/Redo**

### Rationale
Undo/redo is expected in any editor. It enables experimentation and error recovery. This is a quality-of-life feature that significantly improves UX.

### Effort
**L (2–4 days)**

### Priority
**P2 (Medium)**

### Technical Requirements
- Command pattern implementation
- History stack management
- Undo/redo operations
- Keyboard shortcuts
- State serialization

### Windsurf Best-Practices Prompt
```text
Implement undo/redo system for ExFlow using command pattern.

Requirements:
1. Command protocol:
   ```elixir
   defprotocol ExFlow.Command do
     @spec execute(t(), Graph.t()) :: {:ok, Graph.t()} | {:error, term()}
     @spec undo(t(), Graph.t()) :: {:ok, Graph.t()} | {:error, term()}
     @spec description(t()) :: String.t()
   end
   ```

2. Command implementations:
   - CreateNodeCommand
   - DeleteNodeCommand
   - MoveNodeCommand
   - CreateEdgeCommand
   - DeleteEdgeCommand

3. History manager:
   - Track command stack (past, future)
   - Max history size (default: 50)
   - Clear future on new command
   - Serialize for persistence (optional)

4. LiveView integration:
   - Handle "undo" and "redo" events
   - Update graph via command execution
   - Broadcast changes via PubSub
   - Show undo/redo availability in UI

5. Keyboard shortcuts:
   - Cmd/Ctrl+Z: undo
   - Cmd/Ctrl+Shift+Z: redo
   - Show command description in UI

6. Edge cases:
   - Can't undo past initial state
   - Can't redo if no future commands
   - Handle command execution failures
   - Merge consecutive move commands (optional)

Keep commands immutable and serializable.
Add tests for all command types.
Consider memory usage with large histories.
```

### Acceptance Criteria
- [ ] Can undo last operation
- [ ] Can redo undone operation
- [ ] Keyboard shortcuts work
- [ ] History limit enforced
- [ ] All operations support undo

---

## Set 10 — Real-Time Collaboration (PubSub)

### Title
**Add Multi-User Real-Time Collaboration**

### Rationale
Collaboration is a key differentiator. Multiple users editing the same graph simultaneously enables team workflows.

### Effort
**XL (5–10 days)**

### Priority
**P2 (Medium)**

### Technical Requirements
- PubSub topic per graph
- Presence tracking
- Cursor sharing
- Conflict resolution
- Operational transforms or CRDTs

### Windsurf Best-Practices Prompt
```text
Implement real-time collaboration for ExFlow using Phoenix PubSub and Presence.

Requirements:
1. PubSub setup:
   - Topic per graph: "graph:#{graph_id}"
   - Subscribe on LiveView mount
   - Broadcast all graph mutations
   - Handle incoming broadcasts

2. Presence tracking:
   - Use Phoenix.Presence
   - Track user_id, name, color
   - Show active users in UI
   - Display user cursors on canvas

3. Cursor sharing:
   - Broadcast cursor position on mousemove (throttled)
   - Render other users' cursors
   - Show user name/color on cursor
   - Hide cursor after inactivity

4. Conflict resolution:
   - Optimistic locking with version numbers
   - Detect concurrent modifications
   - Merge strategies:
     - Last-write-wins for moves
     - Operational transform for structure changes
   - Show conflict UI when needed

5. Node locking:
   - Lock node when user starts dragging
   - Broadcast lock/unlock events
   - Show locked state in UI
   - Auto-unlock on disconnect

6. Performance:
   - Throttle cursor broadcasts (100ms)
   - Debounce graph updates (500ms)
   - Use delta updates, not full graph
   - Compress large payloads

7. Edge cases:
   - Handle disconnects gracefully
   - Reconcile state on reconnect
   - Prevent race conditions
   - Test with 10+ concurrent users

Keep collaboration optional (single-user mode still works).
Add feature flag for collaboration.
Document collaboration architecture.
```

### Acceptance Criteria
- [ ] Multiple users can edit simultaneously
- [ ] Cursors are visible
- [ ] Conflicts are resolved
- [ ] Performance stays good
- [ ] Disconnects handled gracefully

---

## Priority Summary

### P0 (Critical - Do First)
1. **Set 1:** Stabilize Build + Test
2. **Set 2:** Graph Contract + Serialization
3. **Set 3:** Pan/Zoom

### P1 (High - Core Features)
4. **Set 4:** Edge Creation
5. **Set 5:** Ecto Adapter
6. **Set 6:** Performance Optimization
7. **Set 7:** Node Creation/Deletion

### P2 (Medium - Quality of Life)
8. **Set 8:** Selection & Multi-Select
9. **Set 9:** Undo/Redo
10. **Set 10:** Real-Time Collaboration

### P3 (Nice to Have - Future)
- Export/Import (JSON, PNG, SVG)
- Templates & Snippets
- Minimap
- Search & Filter
- Execution Engine
- Mobile Support

---

## Estimated Timeline

**Minimum Viable Product (MVP):**
- Sets 1-4: ~2-3 weeks
- Result: Functional node editor with basic features

**Production Ready:**
- Sets 1-7: ~4-6 weeks
- Result: Performant editor with persistence

**Full Featured:**
- Sets 1-10: ~8-12 weeks
- Result: Collaborative editor with all features

---

## Tips for Using These Prompts

1. **Copy the entire prompt** including constraints and requirements
2. **Paste into Windsurf** or your LLM of choice
3. **Review the generated code** before committing
4. **Run tests** after each set
5. **Update this document** as you complete sets

---

**Document Version:** 1.0  
**Last Updated:** January 26, 2026  
**Next Review:** After completing Set 3
