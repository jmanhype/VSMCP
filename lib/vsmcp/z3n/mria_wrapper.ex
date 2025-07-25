defmodule Vsmcp.Z3n.MriaWrapper do
  @moduledoc """
  Z3n.Mria Wrapper - Distributed table management with Mnesia/Riak Core principles.
  
  Provides:
  - Distributed table creation and management
  - Shard/table/node helpers for data distribution
  - Goldrush event integration for real-time monitoring
  - Automatic replication and consistency management
  """
  
  use GenServer
  require Logger
  
  @type shard_id :: non_neg_integer()
  @type table_name :: atom()
  @type node_id :: node()
  @type consistency_level :: :eventual | :strong | :causal
  
  @default_shard_count 64
  @replication_factor 3
  
  # Table configuration
  @table_config %{
    vsm_states: %{
      type: :set,
      attributes: [:id, :zone, :variety_level, :timestamp, :data],
      index: [:zone, :variety_level],
      disc_copies: true
    },
    variety_gaps: %{
      type: :ordered_set,
      attributes: [:id, :gap_size, :zone, :timestamp, :recommendations],
      index: [:zone, :gap_size],
      disc_copies: true
    },
    security_events: %{
      type: :bag,
      attributes: [:id, :event_type, :threat_level, :timestamp, :details],
      index: [:event_type, :threat_level],
      disc_only_copies: true
    },
    mcp_capabilities: %{
      type: :set,
      attributes: [:id, :capability, :server, :installed_at, :metadata],
      index: [:capability, :server],
      ram_copies: true
    }
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def create_table(name, config \\ %{}) do
    GenServer.call(__MODULE__, {:create_table, name, config})
  end
  
  def write(table, record, consistency \\ :eventual) do
    GenServer.call(__MODULE__, {:write, table, record, consistency})
  end
  
  def read(table, key, consistency \\ :eventual) do
    GenServer.call(__MODULE__, {:read, table, key, consistency})
  end
  
  def query(table, match_spec, opts \\ []) do
    GenServer.call(__MODULE__, {:query, table, match_spec, opts})
  end
  
  def get_shard(key) do
    GenServer.call(__MODULE__, {:get_shard, key})
  end
  
  def get_nodes_for_shard(shard_id) do
    GenServer.call(__MODULE__, {:get_nodes_for_shard, shard_id})
  end
  
  def add_node(node) do
    GenServer.call(__MODULE__, {:add_node, node})
  end
  
  def remove_node(node) do
    GenServer.call(__MODULE__, {:remove_node, node})
  end
  
  def rebalance_shards do
    GenServer.cast(__MODULE__, :rebalance_shards)
  end
  
  # Goldrush event integration
  def subscribe_events(event_types) do
    GenServer.call(__MODULE__, {:subscribe_events, event_types})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    # Initialize Mnesia if not already started
    ensure_mnesia_started()
    
    # Create schema if needed
    ensure_schema_exists()
    
    # Initialize consistent hashing ring
    ring = initialize_hash_ring()
    
    # Start Goldrush event manager
    {:ok, event_mgr} = start_event_manager()
    
    # Schedule periodic health checks
    :timer.send_interval(30_000, :health_check)
    
    {:ok, %{
      tables: %{},
      ring: ring,
      nodes: [node()],
      shard_count: @default_shard_count,
      event_manager: event_mgr,
      subscriptions: %{},
      stats: %{
        reads: 0,
        writes: 0,
        queries: 0
      }
    }}
  end
  
  @impl true
  def handle_call({:create_table, name, custom_config}, _from, state) do
    config = Map.merge(@table_config[name] || %{}, custom_config)
    
    case create_distributed_table(name, config, state.nodes) do
      :ok ->
        # Emit table creation event
        emit_event(:table_created, %{table: name, config: config})
        
        new_state = put_in(state.tables[name], config)
        {:reply, :ok, new_state}
        
      {:error, reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:write, table, record, consistency}, _from, state) do
    # Determine shard based on record key
    key = elem(record, 1)  # Assuming first element after record tag is the key
    shard_id = calculate_shard(key, state.shard_count)
    
    # Get nodes responsible for this shard
    nodes = get_shard_nodes(shard_id, state.ring, state.nodes)
    
    # Write based on consistency level
    result = case consistency do
      :strong ->
        write_strong_consistency(table, record, nodes)
      :causal ->
        write_causal_consistency(table, record, nodes)
      :eventual ->
        write_eventual_consistency(table, record, nodes)
    end
    
    # Update stats and emit event
    new_state = update_in(state.stats.writes, &(&1 + 1))
    emit_event(:data_written, %{table: table, shard: shard_id, consistency: consistency})
    
    {:reply, result, new_state}
  end
  
  @impl true
  def handle_call({:read, table, key, consistency}, _from, state) do
    shard_id = calculate_shard(key, state.shard_count)
    nodes = get_shard_nodes(shard_id, state.ring, state.nodes)
    
    result = case consistency do
      :strong ->
        read_strong_consistency(table, key, nodes)
      :causal ->
        read_causal_consistency(table, key, nodes)
      :eventual ->
        read_eventual_consistency(table, key, nodes)
    end
    
    new_state = update_in(state.stats.reads, &(&1 + 1))
    {:reply, result, new_state}
  end
  
  @impl true
  def handle_call({:query, table, match_spec, opts}, _from, state) do
    # Distributed query across all relevant shards
    result = distributed_query(table, match_spec, opts, state.nodes)
    
    new_state = update_in(state.stats.queries, &(&1 + 1))
    emit_event(:query_executed, %{table: table, opts: opts})
    
    {:reply, result, new_state}
  end
  
  @impl true
  def handle_call({:get_shard, key}, _from, state) do
    shard_id = calculate_shard(key, state.shard_count)
    {:reply, shard_id, state}
  end
  
  @impl true
  def handle_call({:get_nodes_for_shard, shard_id}, _from, state) do
    nodes = get_shard_nodes(shard_id, state.ring, state.nodes)
    {:reply, nodes, state}
  end
  
  @impl true
  def handle_call({:add_node, new_node}, _from, state) do
    if new_node in state.nodes do
      {:reply, {:error, :already_member}, state}
    else
      # Add node to cluster
      :net_kernel.connect_node(new_node)
      
      # Update ring
      new_ring = add_node_to_ring(new_node, state.ring)
      new_nodes = [new_node | state.nodes]
      
      # Trigger rebalancing
      send(self(), :rebalance_shards)
      
      emit_event(:node_added, %{node: new_node})
      
      {:reply, :ok, %{state | nodes: new_nodes, ring: new_ring}}
    end
  end
  
  @impl true
  def handle_call({:subscribe_events, event_types}, {pid, _}, state) do
    # Subscribe process to specific event types
    new_subscriptions = Enum.reduce(event_types, state.subscriptions, fn event_type, subs ->
      Map.update(subs, event_type, [pid], &[pid | &1])
    end)
    
    {:reply, :ok, %{state | subscriptions: new_subscriptions}}
  end
  
  @impl true
  def handle_cast(:rebalance_shards, state) do
    Task.start(fn ->
      rebalance_data(state.tables, state.ring, state.nodes)
    end)
    
    emit_event(:rebalance_started, %{nodes: length(state.nodes)})
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:health_check, state) do
    # Check health of all nodes
    healthy_nodes = Enum.filter(state.nodes, &node_healthy?/1)
    
    if length(healthy_nodes) < length(state.nodes) do
      Logger.warn("Unhealthy nodes detected: #{inspect(state.nodes -- healthy_nodes)}")
      emit_event(:unhealthy_nodes, %{nodes: state.nodes -- healthy_nodes})
    end
    
    {:noreply, %{state | nodes: healthy_nodes}}
  end
  
  @impl true
  def handle_info({:goldrush_event, event}, state) do
    # Forward Goldrush events to subscribers
    broadcast_event(event, state.subscriptions)
    {:noreply, state}
  end
  
  # Private Functions - Mnesia/Table Management
  
  defp ensure_mnesia_started do
    case :mnesia.system_info(:is_running) do
      :no ->
        :mnesia.start()
      _ ->
        :ok
    end
  end
  
  defp ensure_schema_exists do
    case :mnesia.create_schema([node()]) do
      :ok -> :ok
      {:error, {_, {:already_exists, _}}} -> :ok
      error -> error
    end
  end
  
  defp create_distributed_table(name, config, nodes) do
    table_def = [
      attributes: config[:attributes] || [:id, :data],
      type: config[:type] || :set,
      index: config[:index] || []
    ]
    
    # Add storage type based on config
    table_def = if config[:disc_copies] do
      [{:disc_copies, nodes} | table_def]
    else
      if config[:disc_only_copies] do
        [{:disc_only_copies, nodes} | table_def]
      else
        [{:ram_copies, nodes} | table_def]
      end
    end
    
    case :mnesia.create_table(name, table_def) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, ^name}} -> :ok
      {:aborted, reason} -> {:error, reason}
    end
  end
  
  # Private Functions - Consistent Hashing
  
  defp initialize_hash_ring do
    # Create a consistent hash ring for shard distribution
    ring_size = 1024  # Virtual nodes per physical node
    
    %{
      size: ring_size,
      nodes: %{},
      vnodes: []
    }
  end
  
  defp calculate_shard(key, shard_count) do
    :erlang.phash2(key, shard_count)
  end
  
  defp get_shard_nodes(shard_id, ring, nodes) do
    # Get N nodes responsible for this shard (N = replication factor)
    # Simplified version - in production, use proper consistent hashing
    start_idx = rem(shard_id, length(nodes))
    
    Stream.cycle(nodes)
    |> Stream.drop(start_idx)
    |> Enum.take(@replication_factor)
    |> Enum.uniq()
  end
  
  defp add_node_to_ring(node, ring) do
    # Add virtual nodes for the new physical node
    vnodes = for i <- 1..128 do
      hash = :erlang.phash2({node, i})
      {hash, node}
    end
    
    %{ring | 
      nodes: Map.put(ring.nodes, node, vnodes),
      vnodes: Enum.sort(ring.vnodes ++ vnodes)
    }
  end
  
  # Private Functions - Consistency Implementations
  
  defp write_strong_consistency(table, record, nodes) do
    # Write to all replicas and wait for all confirmations
    tasks = Enum.map(nodes, fn node ->
      Task.async(fn ->
        :rpc.call(node, :mnesia, :write, [table, record, :write])
      end)
    end)
    
    results = Task.await_many(tasks, 5000)
    
    if Enum.all?(results, &(&1 == :ok)) do
      :ok
    else
      {:error, :write_failed}
    end
  end
  
  defp write_causal_consistency(table, record, nodes) do
    # Write to majority of replicas
    required_acks = div(length(nodes), 2) + 1
    
    tasks = Enum.map(nodes, fn node ->
      Task.async(fn ->
        :rpc.call(node, :mnesia, :write, [table, record, :write])
      end)
    end)
    
    # Wait for majority
    {completed, _pending} = Task.yield_many(tasks, 3000)
    successful = Enum.count(completed, fn {_task, {:ok, result}} -> result == :ok end)
    
    if successful >= required_acks do
      :ok
    else
      {:error, :insufficient_acks}
    end
  end
  
  defp write_eventual_consistency(table, record, nodes) do
    # Write to any available node and return immediately
    node = Enum.random(nodes)
    
    Task.start(fn ->
      :rpc.call(node, :mnesia, :write, [table, record, :write])
      
      # Async replicate to other nodes
      other_nodes = nodes -- [node]
      Enum.each(other_nodes, fn n ->
        Task.start(fn ->
          :rpc.call(n, :mnesia, :write, [table, record, :write])
        end)
      end)
    end)
    
    :ok
  end
  
  defp read_strong_consistency(table, key, nodes) do
    # Read from all nodes and ensure consistency
    tasks = Enum.map(nodes, fn node ->
      Task.async(fn ->
        :rpc.call(node, :mnesia, :read, [table, key])
      end)
    end)
    
    results = Task.await_many(tasks, 5000)
    |> Enum.map(fn
      {:ok, []} -> nil
      {:ok, [record]} -> record
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    
    case results do
      [] -> {:ok, nil}
      [record] -> {:ok, record}
      multiple -> 
        # Conflict - use timestamp or version to resolve
        {:ok, resolve_conflict(multiple)}
    end
  end
  
  defp read_causal_consistency(table, key, nodes) do
    # Read from majority
    required_reads = div(length(nodes), 2) + 1
    
    tasks = Enum.map(nodes, fn node ->
      Task.async(fn ->
        :rpc.call(node, :mnesia, :read, [table, key])
      end)
    end)
    
    {completed, _} = Task.yield_many(tasks, 3000)
    
    valid_results = completed
    |> Enum.map(fn
      {_task, {:ok, {:ok, []}}} -> nil
      {_task, {:ok, {:ok, [record]}}} -> record
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    
    if length(valid_results) >= required_reads do
      {:ok, List.first(valid_results)}
    else
      {:error, :insufficient_reads}
    end
  end
  
  defp read_eventual_consistency(table, key, nodes) do
    # Read from any available node
    node = Enum.random(nodes)
    
    case :rpc.call(node, :mnesia, :read, [table, key]) do
      {:ok, []} -> {:ok, nil}
      {:ok, [record]} -> {:ok, record}
      error -> error
    end
  end
  
  defp distributed_query(table, match_spec, opts, nodes) do
    # Execute query across all nodes and merge results
    limit = Keyword.get(opts, :limit, :infinity)
    
    tasks = Enum.map(nodes, fn node ->
      Task.async(fn ->
        :rpc.call(node, :mnesia, :select, [table, match_spec, limit])
      end)
    end)
    
    results = Task.await_many(tasks, 10000)
    |> Enum.flat_map(fn
      {:ok, records} when is_list(records) -> records
      _ -> []
    end)
    |> Enum.uniq()
    
    # Apply limit if specified
    if is_integer(limit) do
      Enum.take(results, limit)
    else
      results
    end
  end
  
  defp node_healthy?(node) do
    case :net_adm.ping(node) do
      :pong -> true
      :pang -> false
    end
  end
  
  defp resolve_conflict(records) do
    # Simple conflict resolution - choose record with latest timestamp
    # In production, use vector clocks or similar
    Enum.max_by(records, fn record ->
      # Assuming timestamp is in position 4
      elem(record, 4)
    end)
  end
  
  defp rebalance_data(tables, ring, nodes) do
    # Rebalance data across nodes after topology change
    Enum.each(tables, fn {table_name, _config} ->
      # Get all records
      all_records = :mnesia.dirty_all_keys(table_name)
      |> Enum.map(&:mnesia.dirty_read(table_name, &1))
      |> List.flatten()
      
      # Redistribute based on new ring
      Enum.each(all_records, fn record ->
        key = elem(record, 1)
        shard_id = calculate_shard(key, @default_shard_count)
        new_nodes = get_shard_nodes(shard_id, ring, nodes)
        
        # Ensure record exists on new nodes
        Enum.each(new_nodes, fn node ->
          :rpc.call(node, :mnesia, :write, [table_name, record, :write])
        end)
      end)
    end)
    
    Logger.info("Rebalancing completed")
  end
  
  # Private Functions - Event Management
  
  defp start_event_manager do
    # In production, use proper Goldrush setup
    # This is a simplified event manager
    {:ok, self()}
  end
  
  defp emit_event(event_type, data) do
    event = %{
      type: event_type,
      data: data,
      timestamp: DateTime.utc_now(),
      node: node()
    }
    
    # Send to local process for now
    send(self(), {:goldrush_event, event})
    
    # In production, use Goldrush
    # :goldrush_manager.async_stream(event)
  end
  
  defp broadcast_event(event, subscriptions) do
    subscribers = Map.get(subscriptions, event.type, [])
    
    Enum.each(subscribers, fn pid ->
      if Process.alive?(pid) do
        send(pid, {:z3n_event, event})
      end
    end)
  end
end