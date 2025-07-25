defmodule Vsmcp.CRDT.Types.GCounter do
  @moduledoc """
  Grow-only Counter CRDT implementation.
  Supports only increment operations and converges to the maximum value seen.
  """

  @behaviour Vsmcp.CRDT.Behaviour

  defstruct node_id: nil, counters: %{}

  @type t :: %__MODULE__{
    node_id: term(),
    counters: %{term() => non_neg_integer()}
  }

  @impl true
  def new(node_id) do
    %__MODULE__{node_id: node_id, counters: %{node_id => 0}}
  end

  @impl true
  def mutate(%__MODULE__{node_id: node_id, counters: counters} = crdt, {:increment, value})
      when is_integer(value) and value > 0 do
    current = Map.get(counters, node_id, 0)
    new_value = current + value
    new_counters = Map.put(counters, node_id, new_value)
    
    new_crdt = %{crdt | counters: new_counters}
    delta = %__MODULE__{node_id: node_id, counters: %{node_id => new_value}}
    
    {new_crdt, delta}
  end

  def mutate(crdt, {:increment, _value}), do: {crdt, crdt}

  @impl true
  def merge(%__MODULE__{counters: counters1}, %__MODULE__{counters: counters2}) do
    merged_counters = 
      Map.merge(counters1, counters2, fn _k, v1, v2 -> max(v1, v2) end)
    
    %__MODULE__{
      node_id: nil,  # merged states don't have a specific node_id
      counters: merged_counters
    }
  end

  @impl true
  def value(%__MODULE__{counters: counters}) do
    Enum.reduce(counters, 0, fn {_node, count}, acc -> acc + count end)
  end

  @impl true
  def equal?(%__MODULE__{counters: c1}, %__MODULE__{counters: c2}) do
    Map.equal?(c1, c2)
  end

  @impl true
  def causal_context(%__MODULE__{counters: counters}) do
    # For G-Counter, the causal context is the set of all node-value pairs
    counters
  end

  @doc """
  Increment the counter by 1.
  """
  def increment(crdt) do
    mutate(crdt, {:increment, 1})
  end

  @doc """
  Increment the counter by a specific value.
  """
  def increment(crdt, value) when is_integer(value) and value > 0 do
    mutate(crdt, {:increment, value})
  end
end