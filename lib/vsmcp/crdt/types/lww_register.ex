defmodule Vsmcp.CRDT.Types.LWWRegister do
  @moduledoc """
  Last-Write-Wins Register CRDT implementation.
  Uses timestamps to resolve conflicts, with node_id as tiebreaker.
  """

  @behaviour Vsmcp.CRDT.Behaviour

  defstruct node_id: nil, value: nil, timestamp: 0

  @type t :: %__MODULE__{
    node_id: term(),
    value: term(),
    timestamp: integer()
  }

  @impl true
  def new(node_id) do
    %__MODULE__{
      node_id: node_id,
      value: nil,
      timestamp: 0
    }
  end

  @impl true
  def mutate(%__MODULE__{node_id: node_id}, {:set, value}) do
    timestamp = System.monotonic_time()
    
    new_crdt = %__MODULE__{
      node_id: node_id,
      value: value,
      timestamp: timestamp
    }
    
    # Delta is the same as the new state for LWW-Register
    {new_crdt, new_crdt}
  end

  @impl true
  def merge(%__MODULE__{} = crdt1, %__MODULE__{} = crdt2) do
    cond do
      # If timestamps are different, take the one with higher timestamp
      crdt1.timestamp > crdt2.timestamp ->
        crdt1
      
      crdt1.timestamp < crdt2.timestamp ->
        crdt2
      
      # If timestamps are equal, use node_id as tiebreaker for deterministic behavior
      # In case of nil node_id (merged states), compare values directly
      true ->
        if compare_for_tiebreak(crdt1, crdt2) >= 0 do
          crdt1
        else
          crdt2
        end
    end
  end

  @impl true
  def value(%__MODULE__{value: value}) do
    value
  end

  @impl true
  def equal?(%__MODULE__{value: v1, timestamp: t1}, %__MODULE__{value: v2, timestamp: t2}) do
    v1 == v2 and t1 == t2
  end

  @impl true
  def causal_context(%__MODULE__{timestamp: timestamp, node_id: node_id}) do
    %{timestamp: timestamp, node_id: node_id}
  end

  @doc """
  Set the value of the register.
  """
  def set(crdt, value) do
    mutate(crdt, {:set, value})
  end

  @doc """
  Get the current value of the register.
  """
  def get(crdt) do
    value(crdt)
  end

  # Helper function for deterministic tiebreaking
  defp compare_for_tiebreak(%__MODULE__{node_id: id1, value: v1}, 
                            %__MODULE__{node_id: id2, value: v2}) do
    cond do
      id1 != nil and id2 != nil ->
        # Compare node IDs
        compare_terms(id1, id2)
      
      true ->
        # If either node_id is nil, compare values
        compare_terms(v1, v2)
    end
  end

  defp compare_terms(t1, t2) do
    cond do
      t1 > t2 -> 1
      t1 < t2 -> -1
      true -> 0
    end
  end
end