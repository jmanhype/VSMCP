defmodule Vsmcp.CRDT.Types.PNCounter do
  @moduledoc """
  Positive-Negative Counter CRDT implementation.
  Supports both increment and decrement operations using two G-Counters internally.
  """

  @behaviour Vsmcp.CRDT.Behaviour

  alias Vsmcp.CRDT.Types.GCounter

  defstruct node_id: nil, positive: nil, negative: nil

  @type t :: %__MODULE__{
    node_id: term(),
    positive: GCounter.t(),
    negative: GCounter.t()
  }

  @impl true
  def new(node_id) do
    %__MODULE__{
      node_id: node_id,
      positive: GCounter.new(node_id),
      negative: GCounter.new(node_id)
    }
  end

  @impl true
  def mutate(%__MODULE__{node_id: node_id} = crdt, {:increment, value})
      when is_integer(value) and value > 0 do
    {new_positive, positive_delta} = GCounter.mutate(crdt.positive, {:increment, value})
    
    new_crdt = %{crdt | positive: new_positive}
    delta = %__MODULE__{
      node_id: node_id,
      positive: positive_delta,
      negative: GCounter.new(node_id)
    }
    
    {new_crdt, delta}
  end

  def mutate(%__MODULE__{node_id: node_id} = crdt, {:decrement, value})
      when is_integer(value) and value > 0 do
    {new_negative, negative_delta} = GCounter.mutate(crdt.negative, {:increment, value})
    
    new_crdt = %{crdt | negative: new_negative}
    delta = %__MODULE__{
      node_id: node_id,
      positive: GCounter.new(node_id),
      negative: negative_delta
    }
    
    {new_crdt, delta}
  end

  def mutate(crdt, _), do: {crdt, crdt}

  @impl true
  def merge(%__MODULE__{positive: p1, negative: n1}, %__MODULE__{positive: p2, negative: n2}) do
    %__MODULE__{
      node_id: nil,
      positive: GCounter.merge(p1, p2),
      negative: GCounter.merge(n1, n2)
    }
  end

  @impl true
  def value(%__MODULE__{positive: positive, negative: negative}) do
    GCounter.value(positive) - GCounter.value(negative)
  end

  @impl true
  def equal?(%__MODULE__{positive: p1, negative: n1}, %__MODULE__{positive: p2, negative: n2}) do
    GCounter.equal?(p1, p2) and GCounter.equal?(n1, n2)
  end

  @impl true
  def causal_context(%__MODULE__{positive: positive, negative: negative}) do
    %{
      positive: GCounter.causal_context(positive),
      negative: GCounter.causal_context(negative)
    }
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

  @doc """
  Decrement the counter by 1.
  """
  def decrement(crdt) do
    mutate(crdt, {:decrement, 1})
  end

  @doc """
  Decrement the counter by a specific value.
  """
  def decrement(crdt, value) when is_integer(value) and value > 0 do
    mutate(crdt, {:decrement, value})
  end
end