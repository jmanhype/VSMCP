defmodule Vsmcp.CRDT.ContextStore do
  @moduledoc """
  High-level API for CRDT-based context storage in the VSM system.
  Provides a unified interface for all CRDT operations with automatic
  synchronization, persistence, and conflict resolution.
  """

  use GenServer
  require Logger

  alias Vsmcp.CRDT.Types.{GCounter, PNCounter, ORSet, LWWRegister}
  alias Vsmcp.CRDT.Storage.TieredStorage
  alias Vsmcp.CRDT.Sync.PubSubSync
  alias Vsmcp.CRDT.HLC

  @type crdt_type :: :g_counter | :pn_counter | :or_set | :lww_register
  @type crdt_id :: term()

  defstruct [
    :node_id,
    :storage,
    :sync,
    :hlc,
    :metadata
  ]

  # Client API

  @doc """
  Start the ContextStore with options.
  
  Options:
    - node_id: Unique identifier for this node
    - storage_opts: Options for tiered storage
    - sync_opts: Options for PubSub synchronization
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Create a new CRDT instance of the specified type.
  """
  def create(server \\ __MODULE__, crdt_id, crdt_type) when crdt_type in [:g_counter, :pn_counter, :or_set, :lww_register] do
    GenServer.call(server, {:create, crdt_id, crdt_type})
  end

  @doc """
  Get the value of a CRDT.
  """
  def get(server \\ __MODULE__, crdt_id) do
    GenServer.call(server, {:get, crdt_id})
  end

  @doc """
  Update a CRDT with an operation.
  
  Operations by type:
    - g_counter: {:increment, value}
    - pn_counter: {:increment, value} | {:decrement, value}
    - or_set: {:add, element} | {:remove, element}
    - lww_register: {:set, value}
  """
  def update(server \\ __MODULE__, crdt_id, operation) do
    GenServer.call(server, {:update, crdt_id, operation})
  end

  @doc """
  Increment a counter CRDT.
  """
  def increment(server \\ __MODULE__, crdt_id, value \\ 1) do
    update(server, crdt_id, {:increment, value})
  end

  @doc """
  Decrement a PN-counter CRDT.
  """
  def decrement(server \\ __MODULE__, crdt_id, value \\ 1) do
    update(server, crdt_id, {:decrement, value})
  end

  @doc """
  Add an element to a set CRDT.
  """
  def add(server \\ __MODULE__, crdt_id, element) do
    update(server, crdt_id, {:add, element})
  end

  @doc """
  Remove an element from a set CRDT.
  """
  def remove(server \\ __MODULE__, crdt_id, element) do
    update(server, crdt_id, {:remove, element})
  end

  @doc """
  Set the value of a register CRDT.
  """
  def set(server \\ __MODULE__, crdt_id, value) do
    update(server, crdt_id, {:set, value})
  end

  @doc """
  List all CRDT IDs in the store.
  """
  def list_crdts(server \\ __MODULE__) do
    GenServer.call(server, :list_crdts)
  end

  @doc """
  Get metadata for a CRDT.
  """
  def get_metadata(server \\ __MODULE__, crdt_id) do
    GenServer.call(server, {:get_metadata, crdt_id})
  end

  @doc """
  Force synchronization with peers.
  """
  def sync(server \\ __MODULE__) do
    GenServer.cast(server, :sync)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    node_id = Keyword.get(opts, :node_id, node())
    
    # Start storage subsystem
    storage_opts = Keyword.get(opts, :storage_opts, [])
    {:ok, storage} = TieredStorage.start_link(storage_opts)
    
    # Start sync subsystem
    sync_opts = Keyword.get(opts, :sync_opts, [])
    {:ok, sync} = PubSubSync.start_link([node_id: node_id] ++ sync_opts)
    
    state = %__MODULE__{
      node_id: node_id,
      storage: storage,
      sync: sync,
      hlc: HLC.new(node_id),
      metadata: %{}
    }
    
    # Load existing CRDTs from storage
    load_existing_crdts(state)
    
    {:ok, state}
  end

  @impl true
  def handle_call({:create, crdt_id, crdt_type}, _from, state) do
    case TieredStorage.get(state.storage, crdt_id) do
      {:ok, _existing} ->
        {:reply, {:error, :already_exists}, state}
      
      {:error, :not_found} ->
        # Create new CRDT instance
        crdt = create_crdt_instance(crdt_type, state.node_id)
        
        # Store in tiered storage
        :ok = TieredStorage.put(state.storage, crdt_id, {crdt_type, crdt})
        
        # Register with sync system
        :ok = PubSubSync.register_crdt(state.sync, crdt_id, crdt_type, crdt)
        
        # Update metadata
        metadata = %{
          type: crdt_type,
          created_at: System.system_time(:millisecond),
          created_by: state.node_id,
          hlc: state.hlc
        }
        new_metadata = Map.put(state.metadata, crdt_id, metadata)
        
        # Update HLC
        new_hlc = HLC.tick(state.hlc)
        
        {:reply, :ok, %{state | metadata: new_metadata, hlc: new_hlc}}
    end
  end

  @impl true
  def handle_call({:get, crdt_id}, _from, state) do
    case TieredStorage.get(state.storage, crdt_id) do
      {:ok, {crdt_type, crdt}} ->
        module = crdt_module(crdt_type)
        value = module.value(crdt)
        {:reply, {:ok, value}, state}
      
      {:error, :not_found} ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:update, crdt_id, operation}, _from, state) do
    case TieredStorage.get(state.storage, crdt_id) do
      {:ok, {crdt_type, crdt}} ->
        module = crdt_module(crdt_type)
        
        # Perform the mutation
        case module.mutate(crdt, operation) do
          {new_crdt, delta} ->
            # Update storage
            :ok = TieredStorage.put(state.storage, crdt_id, {crdt_type, new_crdt})
            
            # Propagate delta
            PubSubSync.propagate_delta(state.sync, crdt_id, delta)
            
            # Update HLC
            new_hlc = HLC.tick(state.hlc)
            
            # Return new value
            value = module.value(new_crdt)
            {:reply, {:ok, value}, %{state | hlc: new_hlc}}
          
          _ ->
            {:reply, {:error, :invalid_operation}, state}
        end
      
      {:error, :not_found} ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:list_crdts, _from, state) do
    crdt_ids = TieredStorage.keys(state.storage)
    {:reply, crdt_ids, state}
  end

  @impl true
  def handle_call({:get_metadata, crdt_id}, _from, state) do
    case Map.get(state.metadata, crdt_id) do
      nil -> {:reply, {:error, :not_found}, state}
      metadata -> {:reply, {:ok, metadata}, state}
    end
  end

  @impl true
  def handle_cast(:sync, state) do
    PubSubSync.sync_now(state.sync)
    {:noreply, state}
  end

  # Private Functions

  defp create_crdt_instance(:g_counter, node_id), do: GCounter.new(node_id)
  defp create_crdt_instance(:pn_counter, node_id), do: PNCounter.new(node_id)
  defp create_crdt_instance(:or_set, node_id), do: ORSet.new(node_id)
  defp create_crdt_instance(:lww_register, node_id), do: LWWRegister.new(node_id)

  defp crdt_module(:g_counter), do: GCounter
  defp crdt_module(:pn_counter), do: PNCounter
  defp crdt_module(:or_set), do: ORSet
  defp crdt_module(:lww_register), do: LWWRegister

  defp load_existing_crdts(state) do
    # Load all CRDTs from storage and register with sync
    TieredStorage.keys(state.storage)
    |> Enum.each(fn crdt_id ->
      case TieredStorage.get(state.storage, crdt_id) do
        {:ok, {crdt_type, crdt}} ->
          PubSubSync.register_crdt(state.sync, crdt_id, crdt_type, crdt)
        
        _ ->
          :ok
      end
    end)
  end
end