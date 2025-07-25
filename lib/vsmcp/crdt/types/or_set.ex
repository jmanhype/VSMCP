defmodule Vsmcp.CRDT.Types.ORSet do
  @moduledoc """
  Observed-Remove Set CRDT implementation.
  Supports add and remove operations with proper causality tracking using unique tags.
  """

  @behaviour Vsmcp.CRDT.Behaviour

  defstruct node_id: nil, elements: %{}, tombstones: %{}

  @type tag :: {node_id :: term(), timestamp :: integer()}
  @type t :: %__MODULE__{
    node_id: term(),
    elements: %{term() => MapSet.t(tag)},
    tombstones: %{term() => MapSet.t(tag)}
  }

  @impl true
  def new(node_id) do
    %__MODULE__{
      node_id: node_id,
      elements: %{},
      tombstones: %{}
    }
  end

  @impl true
  def mutate(%__MODULE__{node_id: node_id, elements: elements} = crdt, {:add, element}) do
    timestamp = System.monotonic_time()
    tag = {node_id, timestamp}
    
    current_tags = Map.get(elements, element, MapSet.new())
    new_tags = MapSet.put(current_tags, tag)
    new_elements = Map.put(elements, element, new_tags)
    
    new_crdt = %{crdt | elements: new_elements}
    delta = %__MODULE__{
      node_id: node_id,
      elements: %{element => MapSet.new([tag])},
      tombstones: %{}
    }
    
    {new_crdt, delta}
  end

  def mutate(%__MODULE__{node_id: node_id, elements: elements, tombstones: tombstones} = crdt, 
             {:remove, element}) do
    case Map.get(elements, element) do
      nil ->
        {crdt, crdt}
      
      tags ->
        # Move all tags to tombstones
        current_tombstones = Map.get(tombstones, element, MapSet.new())
        new_tombstones = MapSet.union(current_tombstones, tags)
        
        new_crdt = %{crdt | 
          elements: Map.delete(elements, element),
          tombstones: Map.put(tombstones, element, new_tombstones)
        }
        
        delta = %__MODULE__{
          node_id: node_id,
          elements: %{},
          tombstones: %{element => tags}
        }
        
        {new_crdt, delta}
    end
  end

  @impl true
  def merge(%__MODULE__{elements: e1, tombstones: t1}, 
            %__MODULE__{elements: e2, tombstones: t2}) do
    # Merge tombstones first
    merged_tombstones = merge_maps(t1, t2)
    
    # Merge elements, but remove any tags that appear in tombstones
    merged_elements = 
      merge_maps(e1, e2)
      |> Enum.map(fn {element, tags} ->
        tombstone_tags = Map.get(merged_tombstones, element, MapSet.new())
        remaining_tags = MapSet.difference(tags, tombstone_tags)
        {element, remaining_tags}
      end)
      |> Enum.reject(fn {_element, tags} -> MapSet.size(tags) == 0 end)
      |> Enum.into(%{})
    
    %__MODULE__{
      node_id: nil,
      elements: merged_elements,
      tombstones: merged_tombstones
    }
  end

  @impl true
  def value(%__MODULE__{elements: elements}) do
    Map.keys(elements) |> MapSet.new()
  end

  @impl true
  def equal?(%__MODULE__{elements: e1, tombstones: t1}, 
             %__MODULE__{elements: e2, tombstones: t2}) do
    Map.equal?(e1, e2) and Map.equal?(t1, t2)
  end

  @impl true
  def causal_context(%__MODULE__{elements: elements, tombstones: tombstones}) do
    %{
      elements: elements,
      tombstones: tombstones
    }
  end

  @doc """
  Add an element to the set.
  """
  def add(crdt, element) do
    mutate(crdt, {:add, element})
  end

  @doc """
  Remove an element from the set.
  """
  def remove(crdt, element) do
    mutate(crdt, {:remove, element})
  end

  @doc """
  Check if an element is in the set.
  """
  def member?(crdt, element) do
    element in value(crdt)
  end

  # Helper function to merge maps of MapSets
  defp merge_maps(map1, map2) do
    Map.merge(map1, map2, fn _k, v1, v2 -> MapSet.union(v1, v2) end)
  end
end