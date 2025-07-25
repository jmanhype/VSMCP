defmodule Vsmcp.CRDT.Storage.TieredStorage do
  @moduledoc """
  Three-tier storage system for CRDTs: Memory → ETS → DETS.
  Provides automatic promotion/demotion based on access patterns.
  """

  use GenServer
  require Logger

  @memory_limit 1000       # Max items in memory
  @ets_limit 10_000       # Max items in ETS
  @access_threshold 10    # Accesses needed for promotion
  @decay_interval 60_000  # 1 minute decay interval

  defstruct [
    :memory_store,
    :ets_table,
    :dets_table,
    :access_counts,
    :decay_timer
  ]

  # Client API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Store a CRDT in the tiered storage system.
  """
  def put(server \\ __MODULE__, key, value) do
    GenServer.call(server, {:put, key, value})
  end

  @doc """
  Retrieve a CRDT from the tiered storage system.
  """
  def get(server \\ __MODULE__, key) do
    GenServer.call(server, {:get, key})
  end

  @doc """
  Delete a CRDT from all storage tiers.
  """
  def delete(server \\ __MODULE__, key) do
    GenServer.call(server, {:delete, key})
  end

  @doc """
  List all keys in the storage system.
  """
  def keys(server \\ __MODULE__) do
    GenServer.call(server, :keys)
  end

  @doc """
  Get storage statistics.
  """
  def stats(server \\ __MODULE__) do
    GenServer.call(server, :stats)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Create ETS table
    ets_name = Keyword.get(opts, :ets_name, :crdt_ets_storage)
    ets_table = :ets.new(ets_name, [:set, :public, :named_table])
    
    # Open DETS table
    dets_name = Keyword.get(opts, :dets_name, :crdt_dets_storage)
    dets_file = Keyword.get(opts, :dets_file, "crdt_storage.dets")
    {:ok, dets_table} = :dets.open_file(dets_name, [
      file: String.to_charlist(dets_file),
      type: :set
    ])
    
    # Schedule decay timer
    decay_timer = Process.send_after(self(), :decay_access_counts, @decay_interval)
    
    state = %__MODULE__{
      memory_store: %{},
      ets_table: ets_table,
      dets_table: dets_table,
      access_counts: %{},
      decay_timer: decay_timer
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call({:put, key, value}, _from, state) do
    # Always write to memory first
    new_memory = Map.put(state.memory_store, key, value)
    
    # Check if we need to demote items from memory
    new_state = 
      if map_size(new_memory) > @memory_limit do
        demote_from_memory(%{state | memory_store: new_memory})
      else
        %{state | memory_store: new_memory}
      end
    
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    {value, new_state} = get_with_promotion(key, state)
    {:reply, value, new_state}
  end

  @impl true
  def handle_call({:delete, key}, _from, state) do
    # Delete from all tiers
    new_memory = Map.delete(state.memory_store, key)
    :ets.delete(state.ets_table, key)
    :dets.delete(state.dets_table, key)
    new_access_counts = Map.delete(state.access_counts, key)
    
    new_state = %{state | 
      memory_store: new_memory,
      access_counts: new_access_counts
    }
    
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:keys, _from, state) do
    memory_keys = Map.keys(state.memory_store)
    ets_keys = :ets.select(state.ets_table, [{{:"$1", :_}, [], [:"$1"]}])
    dets_keys = :dets.select(state.dets_table, [{{:"$1", :_}, [], [:"$1"]}])
    
    all_keys = 
      (memory_keys ++ ets_keys ++ dets_keys)
      |> Enum.uniq()
      |> Enum.sort()
    
    {:reply, all_keys, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      memory_count: map_size(state.memory_store),
      ets_count: :ets.info(state.ets_table, :size),
      dets_count: :dets.info(state.dets_table, :size),
      total_accesses: Map.values(state.access_counts) |> Enum.sum()
    }
    
    {:reply, stats, state}
  end

  @impl true
  def handle_info(:decay_access_counts, state) do
    # Decay access counts to prevent infinite growth
    new_access_counts = 
      state.access_counts
      |> Enum.map(fn {k, v} -> {k, max(0, v - 1)} end)
      |> Enum.reject(fn {_k, v} -> v == 0 end)
      |> Enum.into(%{})
    
    # Schedule next decay
    Process.cancel_timer(state.decay_timer)
    decay_timer = Process.send_after(self(), :decay_access_counts, @decay_interval)
    
    {:noreply, %{state | access_counts: new_access_counts, decay_timer: decay_timer}}
  end

  @impl true
  def terminate(_reason, state) do
    # Close DETS file
    :dets.close(state.dets_table)
    :ok
  end

  # Private Functions

  defp get_with_promotion(key, state) do
    # Update access count
    access_count = Map.get(state.access_counts, key, 0) + 1
    new_access_counts = Map.put(state.access_counts, key, access_count)
    
    # Try memory first
    case Map.get(state.memory_store, key) do
      nil ->
        # Try ETS
        case :ets.lookup(state.ets_table, key) do
          [{^key, value}] ->
            # Consider promotion to memory
            if access_count >= @access_threshold do
              promote_to_memory(key, value, %{state | access_counts: new_access_counts})
            else
              {{:ok, value}, %{state | access_counts: new_access_counts}}
            end
          
          [] ->
            # Try DETS
            case :dets.lookup(state.dets_table, key) do
              [{^key, value}] ->
                # Consider promotion to ETS
                if access_count >= @access_threshold do
                  promote_to_ets(key, value, %{state | access_counts: new_access_counts})
                else
                  {{:ok, value}, %{state | access_counts: new_access_counts}}
                end
              
              [] ->
                {{:error, :not_found}, %{state | access_counts: new_access_counts}}
            end
        end
      
      value ->
        {{:ok, value}, %{state | access_counts: new_access_counts}}
    end
  end

  defp promote_to_memory(key, value, state) do
    new_memory = Map.put(state.memory_store, key, value)
    :ets.delete(state.ets_table, key)
    
    # Check if we need to demote
    new_state = 
      if map_size(new_memory) > @memory_limit do
        demote_from_memory(%{state | memory_store: new_memory})
      else
        %{state | memory_store: new_memory}
      end
    
    {{:ok, value}, new_state}
  end

  defp promote_to_ets(key, value, state) do
    :ets.insert(state.ets_table, {key, value})
    :dets.delete(state.dets_table, key)
    
    # Check if we need to demote from ETS
    new_state = 
      if :ets.info(state.ets_table, :size) > @ets_limit do
        demote_from_ets(state)
      else
        state
      end
    
    {{:ok, value}, new_state}
  end

  defp demote_from_memory(state) do
    # Find least recently accessed item in memory
    {key_to_demote, _} = 
      state.memory_store
      |> Enum.map(fn {k, v} -> {k, v, Map.get(state.access_counts, k, 0)} end)
      |> Enum.min_by(fn {_k, _v, count} -> count end)
      |> then(fn {k, v, _count} -> {k, v} end)
    
    # Move to ETS
    :ets.insert(state.ets_table, {key_to_demote, Map.get(state.memory_store, key_to_demote)})
    new_memory = Map.delete(state.memory_store, key_to_demote)
    
    # Check if ETS needs demotion
    new_state = %{state | memory_store: new_memory}
    if :ets.info(state.ets_table, :size) > @ets_limit do
      demote_from_ets(new_state)
    else
      new_state
    end
  end

  defp demote_from_ets(state) do
    # Get all ETS entries with their access counts
    ets_entries = 
      :ets.tab2list(state.ets_table)
      |> Enum.map(fn {k, v} -> {k, v, Map.get(state.access_counts, k, 0)} end)
      |> Enum.sort_by(fn {_k, _v, count} -> count end)
    
    # Move least accessed to DETS
    case ets_entries do
      [{key_to_demote, value, _count} | _] ->
        :dets.insert(state.dets_table, {key_to_demote, value})
        :ets.delete(state.ets_table, key_to_demote)
      
      [] ->
        :ok
    end
    
    state
  end
end