# Troubleshooting

**Who this is for:** Developers who have encountered an issue with their ExFlowGraph integration.

**What you'll learn:** How to diagnose and fix common problems.

---

### Hooks Not Loading / Component Not Interactive

This is the most common issue, and it's almost always related to the asset pipeline.

-   **Symptom:** The graph renders, but you can't drag nodes, pan, or zoom. No events are fired.
-   **Cause:** The `ExFlowCanvas` JavaScript hook is not being loaded or attached to the LiveView socket.

**Debug Checklist:**
1.  **Check `app.js`:** Ensure you have imported `ExFlowCanvas` and added it to the `hooks` object passed to `LiveSocket`.
2.  **Check Browser Console:** Open your browser's developer tools.
    -   Are there any errors like `ExFlowCanvas is not defined`? This points to an import problem.
    -   Look for the message `phx-hook attribute found but no client hook defined for ExFlowCanvas`. This confirms the hook is not registered on the socket.
3.  **Verify File Paths:** Double-check the path in `import { ExFlowCanvas } from "..."`. It should point to the `ex_flow_graph.js` file inside `deps/ex_flow_graph`.

### CSS Not Applied

-   **Symptom:** The graph is interactive, but it looks like a mess of unstyled text and lines.
-   **Cause:** The `ex_flow_graph.css` file is not being imported.

**Debug Checklist:**
1.  **Check `app.css`:** Ensure `@import "../vendor/ex_flow_graph/ex_flow_graph.css";` (or the equivalent for your setup) is present.
2.  **Check Tailwind Config:** If using Tailwind, make sure the path to the `ex_flow_graph` dependency is in your `tailwind.config.js` `content` array, otherwise Tailwind will purge the component's classes.
3.  **Use Browser Inspector:** Inspect the node elements. Are the `exflow-node` classes present? If so, the CSS rules for those classes are not being loaded.

### Events Not Firing or Having Wrong Payloads

-   **Symptom:** You interact with the graph, but your `on_event` callback doesn't fire, or the payload is not what you expect.

**Debug Checklist:**
1.  **Check the `on_event` Assign:** Make sure you are passing a valid function reference (e.g., `&handle_graph_event/2`). A common mistake is to call the function: `on_event={handle_graph_event(...)}`.
2.  **Check Arity:** Ensure your callback function has the correct arity (2 in this case, for `{event, payload}, graph`).
3.  **Inspect in JavaScript:** As a last resort, you can add a `console.log` inside the `pushEvent` calls in the `ex_flow_graph.js` hook to see the exact payload being sent from the client.

### Ecto Stale Entry Error on Save

-   **Symptom:** Saving the graph fails with `{:error, %Ecto.StaleEntryError{}}`.
-   **Cause:** You are trying to update a graph record with an outdated version number, which means another process or user has modified it since you last loaded it. This is optimistic locking working as intended.
-   **Solution:** See the `Persistence` guide. Your code must `rescue` this error, reload the latest version of the graph from the database, re-apply the user's intended change, and try to save again.
