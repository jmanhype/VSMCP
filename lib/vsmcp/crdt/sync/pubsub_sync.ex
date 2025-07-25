defmodule Vsmcp.CRDT.Sync.PubSubSync do
  @moduledoc """
  Phoenix.PubSub-based synchronization for CRDTs across VSM nodes.
  Handles delta propagation and anti-entropy synchronization.
  """

  use GenServer
  require Logger

  alias Phoenix.PubSub
  alias Vsmcp.CRDT.HLC

  @pubsub_name Vsmcp.PubSub
  @sync_interval 30_000  # 30 seconds for anti-entropy sync

  defstruct [
    :node_id,
    :hlc,
    :crdts,
    :sync_timer,
    :delta_buffer,
    :peers
  ]

  @type crdt_id :: term()
  @type crdt_type :: atom()
  @type delta :: term()

  # Client API

  @doc """
  Start the CRDT synchronization process.
  """
  def start_link(opts) do
    node_id = Keyword.get(opts, :node_id, node())
    GenServer.start_link(__MODULE__, node_id, name: __MODULE__)
  end

  @doc """
  Register a CRDT instance for synchronization.
  """
  def register_crdt(crdt_id, crdt_type, crdt_instance) do
    GenServer.call(__MODULE__, {:register_crdt, crdt_id, crdt_type, crdt_instance})
  end

  @doc """
  Propagate a delta to all peers.
  """
  def propagate_delta(crdt_id, delta) do
    GenServer.cast(__MODULE__, {:propagate_delta, crdt_id, delta})
  end

  @doc """
  Get the current state of a CRDT.
  """
  def get_crdt(crdt_id) do
    GenServer.call(__MODULE__, {:get_crdt, crdt_id})
  end

  @doc """
  Request full state synchronization with peers.
  """
  def sync_now do
    GenServer.cast(__MODULE__, :sync_now)
  end

  # Server Callbacks

  @impl true
  def init(node_id) do
    # Subscribe to CRDT sync topics
    PubSub.subscribe(@pubsub_name, "crdt:sync")
    PubSub.subscribe(@pubsub_name, "crdt:delta")
    PubSub.subscribe(@pubsub_name, "crdt:state_request")
    
    # Schedule periodic anti-entropy sync
    sync_timer = Process.send_after(self(), :anti_entropy_sync, @sync_interval)
    
    state = %__MODULE__{
      node_id: node_id,
      hlc: HLC.new(node_id),
      crdts: %{},
      sync_timer: sync_timer,
      delta_buffer: %{},
      peers: MapSet.new()
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call({:register_crdt, crdt_id, crdt_type, crdt_instance}, _from, state) do
    new_crdts = Map.put(state.crdts, crdt_id, {crdt_type, crdt_instance})
    new_state = %{state | crdts: new_crdts}
    
    # Announce new CRDT to peers
    broadcast_event(:crdt_registered, %{
      node_id: state.node_id,
      crdt_id: crdt_id,
      crdt_type: crdt_type
    })
    
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_crdt, crdt_id}, _from, state) do
    case Map.get(state.crdts, crdt_id) do
      {_type, crdt} -> {:reply, {:ok, crdt}, state}
      nil -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_cast({:propagate_delta, crdt_id, delta}, state) do
    # Update HLC
    new_hlc = HLC.tick(state.hlc)
    
    # Broadcast delta with causality information
    broadcast_event(:delta, %{
      node_id: state.node_id,
      crdt_id: crdt_id,
      delta: delta,
      hlc: new_hlc
    })
    
    {:noreply, %{state | hlc: new_hlc}}
  end

  @impl true
  def handle_cast(:sync_now, state) do
    handle_info(:anti_entropy_sync, state)
  end

  @impl true
  def handle_info(:anti_entropy_sync, state) do
    # Cancel old timer
    Process.cancel_timer(state.sync_timer)
    
    # Perform anti-entropy sync
    perform_anti_entropy_sync(state)
    
    # Schedule next sync
    sync_timer = Process.send_after(self(), :anti_entropy_sync, @sync_interval)
    
    {:noreply, %{state | sync_timer: sync_timer}}
  end

  @impl true
  def handle_info({:crdt_sync, :delta, payload}, state) do
    %{node_id: sender_node, crdt_id: crdt_id, delta: delta, hlc: remote_hlc} = payload
    
    # Ignore our own messages
    if sender_node != state.node_id do
      # Update HLC based on received event
      new_hlc = HLC.receive_event(state.hlc, remote_hlc)
      
      # Apply delta if we have this CRDT
      new_crdts = 
        case Map.get(state.crdts, crdt_id) do
          {crdt_type, crdt} ->
            module = crdt_module(crdt_type)
            merged_crdt = module.merge(crdt, delta)
            Map.put(state.crdts, crdt_id, {crdt_type, merged_crdt})
          
          nil ->
            # Buffer delta for CRDTs we don't have yet
            buffer_delta(state.delta_buffer, crdt_id, delta)
            state.crdts
        end
      
      # Track peer
      new_peers = MapSet.put(state.peers, sender_node)
      
      {:noreply, %{state | hlc: new_hlc, crdts: new_crdts, peers: new_peers}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:crdt_sync, :state_request, payload}, state) do
    %{node_id: requester, crdt_id: crdt_id} = payload
    
    case Map.get(state.crdts, crdt_id) do
      {crdt_type, crdt} ->
        # Send full state to requester
        PubSub.broadcast(@pubsub_name, "crdt:state_response:#{requester}", %{
          crdt_id: crdt_id,
          crdt_type: crdt_type,
          state: crdt,
          hlc: state.hlc
        })
      
      nil ->
        :ok
    end
    
    {:noreply, state}
  end

  @impl true
  def handle_info({:crdt_sync, :crdt_registered, payload}, state) do
    %{node_id: sender_node, crdt_id: crdt_id, crdt_type: _crdt_type} = payload
    
    if sender_node != state.node_id do
      # Check if we have buffered deltas for this CRDT
      case Map.get(state.delta_buffer, crdt_id) do
        nil ->
          :ok
        
        _deltas ->
          # Request full state from the peer
          broadcast_event(:state_request, %{
            node_id: state.node_id,
            crdt_id: crdt_id
          })
      end
      
      # Track peer
      new_peers = MapSet.put(state.peers, sender_node)
      {:noreply, %{state | peers: new_peers}}
    else
      {:noreply, state}
    end
  end

  # Private Functions

  defp perform_anti_entropy_sync(state) do
    # For each CRDT, broadcast current state digest
    Enum.each(state.crdts, fn {crdt_id, {crdt_type, _crdt}} ->
      broadcast_event(:digest, %{
        node_id: state.node_id,
        crdt_id: crdt_id,
        crdt_type: crdt_type,
        hlc: state.hlc
      })
    end)
  end

  defp broadcast_event(event_type, payload) do
    PubSub.broadcast(@pubsub_name, "crdt:#{event_type}", {:crdt_sync, event_type, payload})
  end

  defp buffer_delta(buffer, crdt_id, delta) do
    deltas = Map.get(buffer, crdt_id, [])
    Map.put(buffer, crdt_id, [delta | deltas])
  end

  defp crdt_module(:g_counter), do: Vsmcp.CRDT.Types.GCounter
  defp crdt_module(:pn_counter), do: Vsmcp.CRDT.Types.PNCounter
  defp crdt_module(:or_set), do: Vsmcp.CRDT.Types.ORSet
  defp crdt_module(:lww_register), do: Vsmcp.CRDT.Types.LWWRegister
end