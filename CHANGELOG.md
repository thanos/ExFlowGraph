# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-02-02

### Added

#### Core Features
- Interactive flow graph component library for Phoenix LiveView
- Drag-and-drop node positioning with real-time updates
- Pan and zoom canvas controls with mouse wheel support
- Edge creation by dragging between node handles
- Multi-select nodes with Shift/Cmd+Click
- Marquee selection by dragging on canvas background
- Command pattern implementation for undo/redo operations (up to 50 operations)

#### Node Management
- Support for multiple node types (Task, Agent)
- Customizable node labels and metadata
- Node selection highlighting with visual feedback
- Option/Alt+Click to edit node labels and metadata
- Delete selected nodes with keyboard shortcut

#### Edge Management
- Smooth cubic Bezier curve rendering
- Edge selection and highlighting
- Option/Alt+Click to edit edge labels and metadata
- Automatic edge cleanup when deleting nodes

#### Storage Adapters
- `ExFlow.Storage.InMemory` - Agent-based in-memory storage
- Pluggable storage adapter pattern for custom implementations
- Graph serialization and deserialization support

#### History & Undo/Redo
- Full undo/redo support for all operations
- Command pattern with `ExFlow.HistoryManager`
- Configurable history size (default: 50 operations)
- Command descriptions for better UX

#### Keyboard Shortcuts
- `Cmd/Ctrl+Z` - Undo last operation
- `Cmd/Ctrl+Shift+Z` - Redo undone operation
- `Delete/Backspace` - Delete selected nodes/edges
- `Escape` - Clear selection
- `Cmd/Ctrl+A` - Select all nodes

#### Components
- `ExFlowGraphWeb.ExFlow.Canvas` - Main canvas component with pan/zoom
- `ExFlowGraphWeb.ExFlow.Node` - Draggable node component
- `ExFlowGraphWeb.ExFlow.Edge` - SVG edge rendering component

#### Documentation
- Comprehensive getting started guide
- Installation instructions
- Events and callbacks reference
- Labels and metadata guide
- Undo/redo system documentation
- Customization guide with CSS examples

#### Developer Experience
- Full test coverage (93.8% core library)
- Type checking with Dialyzer
- Code quality with Credo (strict mode)
- Security scanning with Sobelow
- Dependency auditing
- ExDoc documentation with examples
- CI/CD pipeline with GitHub Actions
- Local CI testing scripts

### Supported Versions
- Elixir: 1.16 - 1.20
- OTP: 26 - 28
- Phoenix: ~> 1.8
- Phoenix LiveView: ~> 1.0

### Dependencies
- `phoenix` ~> 1.8
- `phoenix_live_view` ~> 1.0
- `phoenix_html` ~> 4.0
- `libgraph` ~> 0.16
- `jason` ~> 1.2
- `gettext` ~> 1.0.2

[0.1.0]: https://github.com/thanos/ExFlowGraph/releases/tag/v0.1.0
