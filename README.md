# ExFlowGraph

ExFlowGraph is a "batteries-included" Elixir library for building interactive, node-based editors in Phoenix LiveView. It provides a flexible and extensible component for creating visual workflows, state machines, diagramming tools, and more.

![graphs](https://github.com/user-attachments/assets/1b215aeb-01fa-40f0-acb0-ed52b922e9d5)



### Features

-   **LiveView First:** Designed from the ground up to be a seamless part of the LiveView programming model.
-   **Controlled Component:** Your LiveView remains the source of truth for all state, making validation and persistence trivial.
-   **Rich Interactivity:** Out-of-the-box support for dragging, panning, zooming, connecting, and selecting nodes/edges.
-   **Extensible:** Customize node appearance, add toolbars, and build complex user experiences.
-   **Persistence Included:** Comes with patterns and helpers for Ecto-based persistence, including optimistic locking.

## Getting Started

The best way to get started is with the LiveView Quickstart guide. You can have an interactive editor running in your application in under 15 minutes.

1.  **[Installation](docs/01_INSTALLATION.md)**: Add the dependency and configure your assets.
2.  **[LiveView Quickstart](docs/02_QUICKSTART_LIVEVIEW.md)**: Add the component to your LiveView and make it interactive.

## Documentation

-   **[00 - Overview](docs/00_OVERVIEW.md)**
-   **[01 - Installation](docs/01_INSTALLATION.md)**
-   **[02 - LiveView Quickstart](docs/02_QUICKSTART_LIVEVIEW.md)**
-   **[03 - Component API](docs/03_COMPONENT_API.md)**
-   **[04 - Persistence and CRUD](docs/04_PERSISTENCE_AND_CRUD.md)**
-   **[05 - Recipes](docs/05_RECIPES.md)**
-   **[06 - Troubleshooting](docs/06_TROUBLESHOOTING.md)**

## Philosophy

ExFlowGraph follows the "controlled component" pattern. It does not manage its own state. Instead, it renders the graph state you provide and emits events when the user interacts with it. Your LiveView code is the single source of truth, deciding how to update the state in response to these events. This makes the component highly predictable, testable, and easy to integrate with your application's business logic.
