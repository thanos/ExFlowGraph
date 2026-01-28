### E) Verification Plan

This plan outlines the steps to validate that the new documentation accurately reflects the `ExFlowGraph` library *after* the proposed refactoring. It will ensure the quickstart works as advertised and that core functionalities are covered by tests.

#### 1. "Fresh Project" Checklist (Post-Refactoring)

This checklist assumes all items in the "Implementation Gaps & Refactor Plan" marked as **P0** and **P1** have been completed, and the library has been updated to match the proposed API.

1.  **Project Setup:**
    *   Create a brand new Phoenix LiveView project: `mix phx.new my_test_app --live`
    *   Add `ex_flow_graph` to `mix.exs` dependencies (using the refactored version).
    *   Run `mix deps.get`.
    *   (If applicable, post-refactor) Run any proposed `mix ex_flow_graph.install` task to copy assets or `mix assets.deploy` if assets are pre-compiled into `priv/static`.
    *   Follow `docs/01_INSTALLATION.md` to manually configure `assets/js/app.js` and `assets/css/app.css` according to the new asset pipeline.
2.  **Quickstart Implementation:**
    *   Copy and paste the complete `GraphLive.ex` example from `docs/02_QUICKSTART_LIVEVIEW.md` into `lib/my_test_app_web/live/graph_live.ex`.
    *   Add the corresponding route to `lib/my_test_app_web/router.ex`.
    *   Add the `MyApp.Graphs` context module as described in `docs/04_PERSISTENCE_AND_CRUD.md` and ensure the Ecto migration is run (`mix ecto.create && mix ecto.migrate`).
3.  **Server Startup:**
    *   Start the Phoenix server: `mix phx.server`.
4.  **Expected Result:**
    *   The Phoenix application compiles without warnings.
    *   Navigating to `/graph` (or the configured route) displays a LiveView page with the ExFlowGraph component.
    *   The initial graph (e.g., "Hello, World!" node) from the `mount/3` function is rendered correctly.
    *   The browser's developer console shows no JavaScript errors related to `ExFlowCanvas`.

#### 2. Smoke Test Checklist (Post-Refactoring User Interactions)

Perform these manual interactions in the browser after completing the "Fresh Project" Checklist.

-   [ ] **Node Drag:**
    *   Drag an existing node.
    *   Verify the node moves smoothly on the canvas.
    *   Verify a `{:node_drag_end, %{...}}` event is logged to the server console via the `on_event` callback.
    *   Refresh the page: the node should remain in its new position (persistence check).
-   [ ] **Canvas Pan/Zoom:**
    *   Drag the canvas background to pan.
    *   Use the mouse wheel to zoom in and out.
    *   Verify the canvas responds correctly.
    *   (Optional, if implemented): Verify `{:viewport_changed, %{...}}` events are logged.
-   [ ] **Edge Creation:**
    *   Drag from a source port (e.g., bottom of a node) to a target port (e.g., top of another node).
    *   Verify a new edge appears visually connecting the nodes.
    *   Verify a `{:edge_created, %{...}}` event is logged to the server console.
    *   Refresh the page: the edge should persist.
-   [ ] **Node Deletion:**
    *   Select a node by clicking it.
    *   Press the `Backspace` or `Delete` key.
    *   Verify the node disappears from the canvas, along with any connected edges.
    *   Verify a `{:nodes_deleted, %{...}}` event is logged to the server console.
    *   Refresh the page: the node should remain deleted.
-   [ ] **Edge Deletion:**
    *   Select an edge.
    *   Press the `Backspace` or `Delete` key.
    *   Verify the edge disappears.
    *   Verify a `{:edges_deleted, %{...}}` event is logged.
    *   Refresh the page: the edge should remain deleted.
-   [ ] **Read-Only Mode:**
    *   Change `read_only={true}` in the LiveView template.
    *   Attempt all interactions (drag, create edge, delete).
    *   Verify no interactions are possible and no events are logged.

#### 3. Automated Test Plan (Post-Refactoring)

-   **Unit Tests (`ExFlow.Graph`):**
    *   Confirm tests exist for `ExFlow.Graph.new/1`, `add_node/2`, `update_node/3`, `delete_node/2`, `add_edge/2`, `delete_edge/2`, ensuring immutability and correct state transformation.
    *   Test `ExFlow.Graph.Serializer.to_map/1` and `from_map/1` for faithful round-trip serialization/deserialization of `%ExFlow.Graph{}` structs.
-   **Integration Tests (LiveView Component):**
    *   **Event Handling:** Write `LiveViewTest` tests that:
        *   Mount a `GraphLive` instance.
        *   Simulate `push_event` calls (from the component's JS hook) with expected payloads (e.g., `:node_drag_end`).
        *   Assert that the `on_event` callback processes the event correctly and updates the `@graph` assign.
    *   **Rendering:** Assert that a minimal graph with a few nodes and edges correctly renders in the component.
    *   **Persistence Layer:** Ensure `MyApp.Graphs` context functions (e.g., `get_graph_by_name`, `save_graph`) have unit tests covering success paths, error handling (e.g., `Ecto.StaleEntryError`), and correct serialization/deserialization.
-   **JavaScript Tests (if applicable):**
    *   If the JavaScript hook has significant logic, add client-side tests (e.g., using `Playwright` or a headless browser setup) to ensure events are correctly emitted with the specified payloads for user interactions.
