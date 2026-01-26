defmodule ExFlow.Core.Graph do
  alias Graph, as: LibGraph

  def new do
    LibGraph.new()
  end

  def add_node(%LibGraph{} = graph, id, type, metadata \\ %{}) when is_binary(id) do
    node = %{
      id: id,
      type: type,
      position: Map.get(metadata, :position, %{x: 0, y: 0}),
      metadata: Map.drop(metadata, [:position])
    }

    LibGraph.add_vertex(graph, id, [node])
  end

  def add_edge(%LibGraph{} = graph, id, source_id, source_handle, target_id, target_handle)
      when is_binary(id) and is_binary(source_id) and is_binary(target_id) do
    edge_meta = %{
      id: id,
      source: source_id,
      source_handle: source_handle,
      target: target_id,
      target_handle: target_handle
    }

    LibGraph.add_edge(graph, source_id, target_id, label: id, metadata: edge_meta)
  end

  def update_node_position(%LibGraph{} = graph, id, %{x: x, y: y}) do
    case LibGraph.vertex_labels(graph, id) do
      [node] when is_map(node) ->
        node = put_in(node, [:position], %{x: x, y: y})
        LibGraph.label_vertex(graph, id, [node])

      _ ->
        graph
    end
  end
end
