defmodule ExFlow.Serializer do
  @moduledoc """
  Serializes and deserializes LibGraph structures to/from JSON-compatible maps.
  """

  alias ExFlow.Core.Graph, as: FlowGraph

  @doc """
  Serializes a LibGraph to a JSON-compatible map.
  """
  @spec serialize(FlowGraph.t()) :: {:ok, map()} | {:error, term()}
  def serialize(graph) do
    {:ok, FlowGraph.to_map(graph)}
  rescue
    e -> {:error, e}
  end

  @doc """
  Deserializes a JSON-compatible map to a LibGraph.
  Handles both atom and string keys from database storage.
  """
  @spec deserialize(map()) :: {:ok, FlowGraph.t()} | {:error, term()}
  def deserialize(data) when is_map(data) do
    # Convert string keys to atom keys for from_map compatibility
    normalized_data = %{
      nodes: get_nodes_from_data(data),
      edges: get_edges_from_data(data)
    }

    FlowGraph.from_map(normalized_data)
  end

  def deserialize(_), do: {:error, :invalid_data}

  defp get_nodes_from_data(data) do
    nodes = data["nodes"] || data[:nodes] || []
    Enum.map(nodes, &normalize_node/1)
  end

  defp get_edges_from_data(data) do
    edges = data["edges"] || data[:edges] || []
    Enum.map(edges, &normalize_edge/1)
  end

  defp normalize_node(node) when is_map(node) do
    %{
      id: node["id"] || node[:id],
      type: atomize(node["type"] || node[:type]),
      position: normalize_position(node["position"] || node[:position]),
      metadata: node["metadata"] || node[:metadata] || %{}
    }
  end

  defp normalize_edge(edge) when is_map(edge) do
    %{
      id: edge["id"] || edge[:id],
      source: edge["source"] || edge[:source],
      source_handle: edge["source_handle"] || edge[:source_handle],
      target: edge["target"] || edge[:target],
      target_handle: edge["target_handle"] || edge[:target_handle]
    }
  end

  defp normalize_position(pos) when is_map(pos) do
    %{
      x: pos["x"] || pos[:x],
      y: pos["y"] || pos[:y]
    }
  end

  defp normalize_position(_), do: %{x: 0, y: 0}

  defp atomize(value) when is_binary(value), do: String.to_existing_atom(value)
  defp atomize(value) when is_atom(value), do: value
  defp atomize(_), do: :unknown
end
