# Installation

**Who this is for:** Developers who have a Phoenix LiveView project and are ready to install ExFlowGraph.

**What you'll build:** A project with ExFlowGraph installed and configured, including the Elixir dependency, JavaScript hooks, and CSS.

---

This guide assumes you have a Phoenix LiveView project running on Phoenix `~> 1.7` and LiveView `~> 0.18`.

### 1. Add the Mix Dependency

Add `ex_flow_graph` to your list of dependencies in `mix.exs`:

```elixir
# mix.exs
def deps do
  [
    ...
    {:ex_flow_graph, "~> 0.1.0"} # Replace with the latest version
  ]
end
```

Then, run `mix deps.get` to install it.

### 2. Configure Your JavaScript Assets

ExFlowGraph relies on a JavaScript hook to provide client-side interactivity. You need to import this hook and add it to your LiveView socket configuration.

**File:** `assets/js/app.js`

```javascript
// assets/js/app.js
import { ExFlowCanvas } from "../vendor/ex_flow_graph/ex_flow_graph" // (1)

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// (2)
let hooks = {
  ExFlowCanvas: ExFlowCanvas
}

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: hooks // (3)
})
```

**Explanation:**

1.  **Import the Hook:** We import the `ExFlowCanvas` hook from the `ex_flow_graph` package. **Note:** The exact path may vary depending on your build tool (esbuild, Vite) and project structure. The key is to point to the `ex_flow_graph.js` file within the dependency.
2.  **Define the Hooks Object:** We create a `hooks` object that maps the name used in the `phx-hook` attribute (`ExFlowCanvas`) to the imported JavaScript object.
3.  **Pass to LiveSocket:** We provide this `hooks` object when creating the `LiveSocket` instance.

### 3. Configure Your CSS

The component comes with default styling for nodes, edges, and the canvas. You'll need to import the CSS file.

**File:** `assets/css/app.css`

```css
/* assets/css/app.css */
@import "../vendor/ex_flow_graph/ex_flow_graph.css";

/* Your other styles here... */
```

**Tailwind CSS Users:**

If you are using Tailwind CSS, you also need to ensure the ExFlowGraph component paths are included in your `tailwind.config.js` file's `content` array so Tailwind can discover the classes it uses.

**File:** `assets/tailwind.config.js`

```javascript
// assets/tailwind.config.js
module.exports = {
  content: [
    './js/**/*.js',
    '../lib/ex_flow_graph_web/**/*.ex',
    '../deps/ex_flow_graph/lib/**/*.ex', // <-- Add this line
  ],
  // ...
}
```

With these steps, your project is ready to start using the ExFlowGraph component.
