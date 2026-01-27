# Real-Time Collaboration

ExFlowGraph supports real-time collaboration, allowing multiple users to edit the same graph simultaneously using Phoenix PubSub and Presence.

## Architecture

### Components

1. **Phoenix.PubSub**: Message broadcasting system
2. **Phoenix.Presence**: User presence tracking
3. **Collaboration Module**: Helper functions for collaboration features
4. **LiveView Integration**: Real-time updates in the UI

### Data Flow

```
User A makes change → Broadcast to PubSub → All connected users receive update → UI updates
```

## Features

### 1. Presence Tracking

Each connected user is tracked with:
- **user_id**: Unique identifier (generated from socket ID)
- **name**: Display name (e.g., "User 1234")
- **color**: Assigned color for visual identification
- **cursor**: Current cursor position (x, y)
- **locked_nodes**: List of nodes currently being edited
- **online_at**: Timestamp of connection

### 2. Real-Time Graph Updates

All graph mutations are broadcast to connected users:

- **Node Creation**: When a user adds a node, all others see it appear
- **Node Deletion**: Deleted nodes disappear for all users
- **Node Movement**: Position updates are broadcast in real-time
- **Edge Creation**: New edges appear for all users
- **Edge Deletion**: Removed edges disappear for all users

### 3. Active Users Display

The UI shows:
- Avatar circles with user initials
- User-specific colors
- Total count of active users
- Tooltips with user names

### 4. Conflict Prevention

Built-in mechanisms to prevent conflicts:
- **Node Locking**: Nodes can be locked during editing (prepared for future)
- **Optimistic Updates**: Local changes apply immediately
- **Broadcast Filtering**: Users don't receive their own broadcasts

## Implementation Details

### PubSub Topics

Each graph has its own topic:
```elixir
"graph:#{graph_id}"
```

For the demo graph:
```elixir
"graph:demo-graph"
```

### Event Types

#### Presence Events
- `presence_diff`: User joined/left

#### Graph Mutation Events
- `node_created`: New node added
- `node_deleted`: Node removed
- `node_moved`: Node position changed
- `edge_created`: New edge added
- `edge_deleted`: Edge removed

#### Collaboration Events (prepared for future)
- `cursor_moved`: User cursor position update
- `node_locked`: User started editing node
- `node_unlocked`: User finished editing node

### Broadcast Structure

All broadcasts include:
```elixir
%{
  user_id: "user-123",
  timestamp: 1234567890,
  # ... event-specific data
}
```

## Usage

### Testing Collaboration

1. **Open Multiple Browser Windows**:
   - Open `http://localhost:4000` in multiple browser tabs or windows
   - Each window represents a different user

2. **Make Changes**:
   - Add a node in one window → See it appear in others
   - Move a node in one window → See it move in others
   - Delete a node in one window → See it disappear in others
   - Create edges → All users see the connections

3. **Observe Active Users**:
   - Check the "Active Users" section in the header
   - Each user has a unique color and avatar
   - Count updates as users join/leave

### Code Example: Broadcasting Changes

```elixir
# In HomeLive event handler
def handle_event("add_node", %{"type" => type}, socket) do
  # ... create node logic ...
  
  # Broadcast to other users
  if socket.assigns.user_id do
    {:ok, node} = FlowGraph.get_node(graph, node_id)
    Collaboration.broadcast_node_created(@storage_id, socket.assigns.user_id, node)
  end
  
  {:noreply, assign(socket, graph: graph)}
end
```

### Code Example: Handling Broadcasts

```elixir
# In HomeLive handle_info
def handle_info({:node_created, %{user_id: user_id, node: node}}, socket) do
  # Don't process our own changes
  if user_id == socket.assigns.user_id do
    {:noreply, socket}
  else
    # Add the node to our graph
    case FlowGraph.add_node(socket.assigns.graph, node.id, node.type, ...) do
      {:ok, graph} -> {:noreply, assign(socket, :graph, graph)}
      {:error, _} -> {:noreply, socket}
    end
  end
end
```

## Performance Considerations

### Current Implementation

- **Immediate Broadcasts**: All changes broadcast immediately
- **Full Updates**: Complete node/edge data sent
- **No Throttling**: Position updates sent on every change

### Future Optimizations

1. **Throttled Position Updates**: Limit position broadcasts to 100ms intervals
2. **Delta Updates**: Send only changed fields, not full objects
3. **Batch Operations**: Group multiple changes into single broadcast
4. **Compression**: Compress large payloads for efficiency
5. **Cursor Throttling**: Limit cursor position updates

## Limitations

### Current Version

1. **No Conflict Resolution**: Last-write-wins for all operations
2. **No Undo Sync**: Undo/redo not synchronized across users
3. **No Cursor Display**: Cursor positions tracked but not rendered
4. **No Node Locking UI**: Locking infrastructure ready but not visualized
5. **Single Graph**: All users edit the same demo graph

### Future Enhancements

1. **Operational Transforms**: Smart conflict resolution
2. **Synchronized Undo/Redo**: Share undo history across users
3. **Visual Cursors**: Show other users' cursors on canvas
4. **Lock Indicators**: Visual feedback for locked nodes
5. **Multi-Graph Support**: Each graph has its own collaboration session
6. **User Authentication**: Real user accounts instead of generated IDs
7. **Permissions**: Read-only vs. edit access
8. **Chat**: Built-in communication between collaborators

## Security Considerations

### Current Implementation

- **No Authentication**: Users identified by socket ID only
- **No Authorization**: All users have full edit access
- **No Validation**: Broadcasts trusted without verification

### Production Requirements

1. **User Authentication**: Integrate with auth system
2. **Authorization**: Role-based access control
3. **Input Validation**: Validate all broadcast data
4. **Rate Limiting**: Prevent broadcast flooding
5. **Audit Logging**: Track all changes with user attribution

## Testing

### Manual Testing

```bash
# Terminal 1: Start server
iex -S mix phx.server

# Browser 1: Open http://localhost:4000
# Browser 2: Open http://localhost:4000 (incognito or different browser)
# Browser 3: Open http://localhost:4000 (another incognito)

# Make changes in any browser and observe updates in others
```

### Automated Testing

```elixir
# Test presence tracking
test "tracks user presence" do
  {:ok, view, _html} = live(conn, "/")
  assert has_element?(view, "[data-role='active-users']")
end

# Test broadcast reception
test "receives node creation broadcasts" do
  {:ok, view, _html} = live(conn, "/")
  
  # Simulate broadcast from another user
  send(view.pid, {:node_created, %{user_id: "other-user", node: node}})
  
  # Verify node appears
  assert has_element?(view, "[data-id='#{node.id}']")
end
```

## Troubleshooting

### Users Not Seeing Updates

1. **Check PubSub**: Ensure PubSub is running in supervision tree
2. **Check Subscription**: Verify `Collaboration.subscribe/1` is called
3. **Check Broadcasts**: Confirm broadcasts are being sent
4. **Check Filtering**: Ensure user_id filtering works correctly

### Presence Not Working

1. **Check Presence Module**: Verify Presence is in supervision tree
2. **Check Tracking**: Confirm `Presence.track/3` is called on mount
3. **Check Topic**: Ensure correct topic name is used
4. **Check Connected**: Only works when `connected?(socket)` is true

### Performance Issues

1. **Too Many Users**: Test with realistic user counts
2. **Too Many Updates**: Implement throttling for high-frequency events
3. **Large Graphs**: Consider delta updates for big graphs
4. **Network Latency**: Test with simulated network delays

## Best Practices

1. **Filter Own Broadcasts**: Always check `user_id` to avoid processing own changes
2. **Handle Errors Gracefully**: Don't crash on invalid broadcast data
3. **Provide Visual Feedback**: Show users when changes are from others
4. **Test Disconnections**: Handle user disconnects properly
5. **Monitor Performance**: Track broadcast frequency and payload sizes

## API Reference

### Collaboration Module

```elixir
# Subscribe to graph updates
Collaboration.subscribe(graph_id)

# Broadcast changes
Collaboration.broadcast_node_created(graph_id, user_id, node)
Collaboration.broadcast_node_deleted(graph_id, user_id, node_id)
Collaboration.broadcast_node_moved(graph_id, user_id, node_id, position)
Collaboration.broadcast_edge_created(graph_id, user_id, edge)
Collaboration.broadcast_edge_deleted(graph_id, user_id, edge_id)

# Cursor and locking (prepared for future)
Collaboration.broadcast_cursor(graph_id, user_id, x, y)
Collaboration.broadcast_lock(graph_id, user_id, node_id)
Collaboration.broadcast_unlock(graph_id, user_id, node_id)

# User management
Collaboration.list_users(graph_id)
Collaboration.generate_user_color()
Collaboration.get_user_id(socket)
```

### Presence Module

```elixir
# Track user presence
Presence.track(pid, topic, user_id, metadata)

# Update user metadata
Presence.update(socket, user_id, metadata)

# List present users
Presence.list(topic)
```

## Conclusion

ExFlowGraph's real-time collaboration enables seamless multi-user editing with minimal latency. The foundation is solid and ready for future enhancements like cursor sharing, node locking, and advanced conflict resolution.
