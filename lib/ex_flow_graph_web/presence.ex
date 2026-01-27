defmodule ExFlowGraphWeb.Presence do
  @moduledoc """
  Tracks presence of users in graph editing sessions.

  Each user is tracked with:
  - user_id: unique identifier
  - name: display name
  - color: assigned color for cursor/avatar
  - cursor: current cursor position (x, y)
  - locked_nodes: list of node IDs currently being edited
  """
  use Phoenix.Presence,
    otp_app: :ex_flow_graph,
    pubsub_server: ExFlowGraph.PubSub
end
