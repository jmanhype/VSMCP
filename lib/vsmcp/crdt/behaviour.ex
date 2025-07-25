defmodule Vsmcp.CRDT.Behaviour do
  @moduledoc """
  Common behaviour for all CRDT types in the VSM system.
  Provides a unified interface for delta-based CRDTs with causality tracking.
  """

  @doc """
  Initialize a new CRDT instance with a unique node identifier.
  """
  @callback new(node_id :: term()) :: crdt :: term()

  @doc """
  Mutate the CRDT and return both the new state and the delta.
  """
  @callback mutate(crdt :: term(), operation :: term()) :: {new_crdt :: term(), delta :: term()}

  @doc """
  Merge a delta or another CRDT instance into the current state.
  """
  @callback merge(crdt :: term(), delta_or_crdt :: term()) :: new_crdt :: term()

  @doc """
  Query the current value of the CRDT.
  """
  @callback value(crdt :: term()) :: value :: term()

  @doc """
  Compare two CRDT states for equality.
  """
  @callback equal?(crdt1 :: term(), crdt2 :: term()) :: boolean()

  @doc """
  Get the causal context of the CRDT for causality tracking.
  """
  @callback causal_context(crdt :: term()) :: context :: term()
end