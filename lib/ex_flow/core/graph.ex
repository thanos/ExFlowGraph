defmodule ExFlow.Core.Graph do
  @moduledoc """
  Immutable graph operations wrapping libgraph with ExFlow node/edge contracts.
  
  ## Node Schema
  %{id: String.t(), type: atom(), position: %{x: number(), y: number()}, metadata: map()}
  
  ## Edge Schema
  %{id: String.t(), source: String.t(), source_handle: String.t(), target: String.t(), target_handle: String.t()}
  """
  
  alias Graph, as: LibGraph
  
  @type graph_node :: %{
    id: String.t(),
    type: atom(),
    position: %{x: number(), y: number()},
    metadata: map()
  }
  
  @type graph_edge :: %{
    id: String.t(),
    source: String.t(),
    source_handle: String.t(),
    target: String.t(),
    target_handle: String.t()
  }
  
  @type t :: LibGraph.t()

  @spec new() :: t()
  def new do
    LibGraph.new()
  end

  @spec add_node(t(), String.t(), atom(), map()) :: {:ok, t()} | {:error, term()}
  def add_node(%LibGraph{} = graph, id, type, metadata \\ %{}) when is_binary(id) do
    position = Map.get(metadata, :position, %{x: 0, y: 0})
    node_metadata = Map.get(metadata, :metadata, %{})
    
    node = %{
      id: id,
      type: type,
      position: position,
      metadata: node_metadata
    }
    
    case validate_node(node) do
      :ok -> {:ok, LibGraph.add_vertex(graph, id, [node])}
      error -> error
    end
  end

  @spec add_edge(t(), String.t(), String.t(), String.t(), String.t(), String.t()) :: {:ok, t()} | {:error, term()}
  def add_edge(%LibGraph{} = graph, id, source_id, source_handle, target_id, target_handle)
      when is_binary(id) and is_binary(source_id) and is_binary(target_id) do
    edge_meta = %{
      id: id,
      source: source_id,
      source_handle: source_handle,
      target: target_id,
      target_handle: target_handle
    }
    
    with :ok <- validate_edge(edge_meta),
         true <- LibGraph.has_vertex?(graph, source_id) || {:error, :source_not_found},
         true <- LibGraph.has_vertex?(graph, target_id) || {:error, :target_not_found} do
      {:ok, LibGraph.add_edge(graph, source_id, target_id, label: edge_meta)}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :vertex_not_found}
    end
  end

  @spec update_node_position(t(), String.t(), %{x: number(), y: number()}) :: {:ok, t()} | {:error, term()}
  def update_node_position(%LibGraph{} = graph, id, %{x: x, y: y}) do
    case LibGraph.vertex_labels(graph, id) do
      [node] when is_map(node) ->
        updated_node = put_in(node, [:position], %{x: x, y: y})
        graph = LibGraph.delete_vertex(graph, id)
        {:ok, LibGraph.add_vertex(graph, id, [updated_node])}

      _ ->
        {:error, :node_not_found}
    end
  end
  
  @spec delete_node(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def delete_node(%LibGraph{} = graph, id) when is_binary(id) do
    if LibGraph.has_vertex?(graph, id) do
      {:ok, LibGraph.delete_vertex(graph, id)}
    else
      {:error, :node_not_found}
    end
  end
  
  @spec delete_edge(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def delete_edge(%LibGraph{} = graph, edge_id) when is_binary(edge_id) do
    case find_edge_by_id(graph, edge_id) do
      {source_id, target_id} ->
        {:ok, LibGraph.delete_edge(graph, source_id, target_id)}
      nil ->
        {:error, :edge_not_found}
    end
  end
  
  @spec get_node(t(), String.t()) :: {:ok, graph_node()} | {:error, term()}
  def get_node(%LibGraph{} = graph, id) when is_binary(id) do
    case LibGraph.vertex_labels(graph, id) do
      [node] when is_map(node) -> {:ok, node}
      _ -> {:error, :node_not_found}
    end
  end
  
  @spec get_nodes(t()) :: [graph_node()]
  def get_nodes(%LibGraph{} = graph) do
    graph
    |> LibGraph.vertices()
    |> Enum.flat_map(fn vertex_id ->
      case LibGraph.vertex_labels(graph, vertex_id) do
        [node] when is_map(node) -> [node]
        _ -> []
      end
    end)
  end
  
  @spec get_edges(t()) :: [graph_edge()]
  def get_edges(%LibGraph{} = graph) do
    graph
    |> LibGraph.edges()
    |> Enum.flat_map(fn edge ->
      case edge.label do
        %{id: _, source: _, target: _, source_handle: _, target_handle: _} = edge_meta -> [edge_meta]
        _ -> []
      end
    end)
  end
  
  @spec validate_node(graph_node()) :: :ok | {:error, term()}
  def validate_node(%{id: id, type: type, position: %{x: x, y: y}, metadata: metadata}) 
      when is_binary(id) and is_atom(type) and is_number(x) and is_number(y) and is_map(metadata) do
    :ok
  end
  def validate_node(_), do: {:error, :invalid_node_schema}
  
  @spec validate_edge(graph_edge()) :: :ok | {:error, term()}
  def validate_edge(%{id: id, source: source, source_handle: sh, target: target, target_handle: th})
      when is_binary(id) and is_binary(source) and is_binary(sh) and is_binary(target) and is_binary(th) do
    :ok
  end
  def validate_edge(_), do: {:error, :invalid_edge_schema}
  
  @spec to_map(t()) :: %{nodes: [graph_node()], edges: [graph_edge()]}
  def to_map(%LibGraph{} = graph) do
    %{
      nodes: get_nodes(graph),
      edges: get_edges(graph)
    }
  end
  
  @spec from_map(%{nodes: [graph_node()], edges: [graph_edge()]}) :: {:ok, t()} | {:error, term()}
  def from_map(%{nodes: nodes, edges: edges}) when is_list(nodes) and is_list(edges) do
    with {:ok, graph_with_nodes} <- add_nodes(new(), nodes),
         {:ok, graph_with_edges} <- add_edges(graph_with_nodes, edges) do
      {:ok, graph_with_edges}
    end
  end
  def from_map(_), do: {:error, :invalid_map_format}
  
  # Private helpers
  
  defp add_nodes(graph, nodes) do
    Enum.reduce_while(nodes, {:ok, graph}, fn node, {:ok, acc_graph} ->
      case add_node(acc_graph, node.id, node.type, %{position: node.position, metadata: node.metadata}) do
        {:ok, new_graph} -> {:cont, {:ok, new_graph}}
        error -> {:halt, error}
      end
    end)
  end
  
  defp add_edges(graph, edges) do
    Enum.reduce_while(edges, {:ok, graph}, fn edge, {:ok, acc_graph} ->
      case add_edge(acc_graph, edge.id, edge.source, edge.source_handle, edge.target, edge.target_handle) do
        {:ok, new_graph} -> {:cont, {:ok, new_graph}}
        error -> {:halt, error}
      end
    end)
  end
  
  defp find_edge_by_id(graph, edge_id) do
    graph
    |> LibGraph.edges()
    |> Enum.find_value(fn edge ->
      case edge.label do
        %{id: ^edge_id} -> {edge.v1, edge.v2}
        _ -> nil
      end
    end)
  end
end
