defmodule Vsmcp.Variety.AutonomousManager do
  @moduledoc """
  Autonomous Variety Management System
  
  Implements:
  - Variety gap detection using Shannon entropy
  - MCP capability discovery and installation
  - Worker scaling based on variety requirements
  - Self-organizing response to environmental changes
  """
  
  use GenServer
  require Logger
  
  alias Vsmcp.Core.VarietyCalculator
  alias Vsmcp.MCP.ServerManager
  alias Vsmcp.Z3n.MriaWrapper
  
  @type variety_metric :: %{
    operational: float(),
    environmental: float(),
    gap: float(),
    entropy: float(),
    timestamp: DateTime.t()
  }
  
  # Thresholds for autonomous actions
  @critical_gap_threshold 0.7  # 70% gap triggers immediate action
  @high_gap_threshold 0.5      # 50% gap triggers planned action
  @entropy_threshold 4.5       # High entropy indicates complex environment
  
  # MCP capability categories
  @capability_categories %{
    data_processing: ["database", "analytics", "etl", "streaming"],
    ai_ml: ["llm", "vision", "nlp", "prediction"],
    integration: ["api", "webhook", "messaging", "events"],
    security: ["auth", "encryption", "monitoring", "compliance"],
    infrastructure: ["scaling", "deployment", "backup", "monitoring"]
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def check_variety_gaps do
    GenServer.call(__MODULE__, :check_variety_gaps)
  end
  
  def discover_capabilities(category \\ nil) do
    GenServer.call(__MODULE__, {:discover_capabilities, category})
  end
  
  def install_capability(capability_id) do
    GenServer.call(__MODULE__, {:install_capability, capability_id})
  end
  
  def scale_workers(adjustment) do
    GenServer.call(__MODULE__, {:scale_workers, adjustment})
  end
  
  def get_recommendations do
    GenServer.call(__MODULE__, :get_recommendations)
  end
  
  def enable_autonomous_mode(enabled \\ true) do
    GenServer.cast(__MODULE__, {:set_autonomous_mode, enabled})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    # Subscribe to variety calculator updates
    Phoenix.PubSub.subscribe(Vsmcp.PubSub, "variety_alerts")
    
    # Schedule periodic checks
    :timer.send_interval(30_000, :periodic_variety_check)  # Every 30 seconds
    :timer.send_interval(300_000, :discover_new_capabilities)  # Every 5 minutes
    
    {:ok, %{
      autonomous_mode: false,
      current_metrics: nil,
      discovered_capabilities: %{},
      installed_capabilities: MapSet.new(),
      recommendations: [],
      worker_pool: initialize_worker_pool(),
      history: :queue.new(),
      action_log: []
    }}
  end
  
  @impl true
  def handle_call(:check_variety_gaps, _from, state) do
    metrics = calculate_variety_metrics()
    
    # Store metrics in distributed table
    MriaWrapper.write(:variety_gaps, {
      :variety_gap,
      :erlang.unique_integer(),
      metrics.gap,
      :operational,
      DateTime.utc_now(),
      generate_recommendations(metrics)
    })
    
    analysis = analyze_variety_gap(metrics)
    new_state = %{state | current_metrics: metrics}
    
    {:reply, {:ok, analysis}, new_state}
  end
  
  @impl true
  def handle_call({:discover_capabilities, category}, _from, state) do
    # Discover MCP servers that could help with variety gaps
    discovered = discover_mcp_capabilities(category, state.current_metrics)
    
    new_discovered = Map.merge(state.discovered_capabilities, discovered)
    new_state = %{state | discovered_capabilities: new_discovered}
    
    {:reply, {:ok, discovered}, new_state}
  end
  
  @impl true
  def handle_call({:install_capability, capability_id}, _from, state) do
    case install_mcp_capability(capability_id, state) do
      {:ok, result} ->
        new_installed = MapSet.put(state.installed_capabilities, capability_id)
        new_state = %{state | installed_capabilities: new_installed}
        
        # Log the action
        action = %{
          type: :capability_installed,
          capability: capability_id,
          timestamp: DateTime.utc_now(),
          result: result
        }
        
        new_state = update_in(new_state.action_log, &[action | &1])
        
        {:reply, {:ok, result}, new_state}
        
      error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:scale_workers, adjustment}, _from, state) do
    new_pool = adjust_worker_pool(state.worker_pool, adjustment, state.current_metrics)
    
    action = %{
      type: :worker_scaling,
      adjustment: adjustment,
      new_size: map_size(new_pool),
      timestamp: DateTime.utc_now()
    }
    
    new_state = %{state | 
      worker_pool: new_pool,
      action_log: [action | state.action_log]
    }
    
    {:reply, {:ok, map_size(new_pool)}, new_state}
  end
  
  @impl true
  def handle_call(:get_recommendations, _from, state) do
    recommendations = if state.current_metrics do
      generate_recommendations(state.current_metrics)
    else
      []
    end
    
    {:reply, recommendations, state}
  end
  
  @impl true
  def handle_cast({:set_autonomous_mode, enabled}, state) do
    Logger.info("Autonomous mode #{if enabled, do: "enabled", else: "disabled"}")
    {:noreply, %{state | autonomous_mode: enabled}}
  end
  
  @impl true
  def handle_info(:periodic_variety_check, state) do
    metrics = calculate_variety_metrics()
    
    # Update history
    new_history = :queue.in(metrics, state.history)
    new_history = if :queue.len(new_history) > 100 do
      {_, h} = :queue.out(new_history)
      h
    else
      new_history
    end
    
    # If autonomous mode is enabled, take action
    new_state = if state.autonomous_mode do
      take_autonomous_action(metrics, %{state | history: new_history})
    else
      %{state | history: new_history, current_metrics: metrics}
    end
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:discover_new_capabilities, state) do
    if state.autonomous_mode && state.current_metrics do
      # Discover capabilities based on current gaps
      Task.start(fn ->
        discover_and_evaluate_capabilities(state.current_metrics)
      end)
    end
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:variety_gap, gap_size}, state) do
    Logger.warn("Variety gap alert received: #{gap_size}")
    
    if state.autonomous_mode do
      # Immediate response to critical gap
      metrics = calculate_variety_metrics()
      new_state = take_autonomous_action(metrics, state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  
  # Private Functions - Variety Calculations
  
  defp calculate_variety_metrics do
    {:ok, operational} = VarietyCalculator.calculate_operational_variety()
    {:ok, environmental} = VarietyCalculator.calculate_environmental_variety()
    
    gap = environmental - operational
    gap_ratio = if operational > 0, do: gap / operational, else: 1.0
    
    # Calculate Shannon entropy for system state
    entropy = calculate_system_entropy()
    
    %{
      operational: operational,
      environmental: environmental,
      gap: gap,
      gap_ratio: gap_ratio,
      entropy: entropy,
      timestamp: DateTime.utc_now()
    }
  end
  
  defp calculate_system_entropy do
    # Get system state distribution
    states = get_system_states()
    total = length(states)
    
    if total == 0 do
      0.0
    else
      # Calculate probability distribution
      frequencies = Enum.frequencies_by(states, & &1.type)
      
      # Shannon entropy: -Σ(p(x) * log2(p(x)))
      frequencies
      |> Enum.reduce(0.0, fn {_type, count}, entropy ->
        probability = count / total
        entropy - (probability * :math.log2(probability))
      end)
    end
  end
  
  defp get_system_states do
    # In production, query actual system states
    # This is simplified for demonstration
    [
      %{type: :processing, load: 0.7},
      %{type: :idle, load: 0.1},
      %{type: :waiting, load: 0.2}
    ]
  end
  
  defp analyze_variety_gap(metrics) do
    severity = cond do
      metrics.gap_ratio > @critical_gap_threshold -> :critical
      metrics.gap_ratio > @high_gap_threshold -> :high
      metrics.gap_ratio > 0.3 -> :medium
      true -> :low
    end
    
    %{
      severity: severity,
      operational_variety: metrics.operational,
      environmental_variety: metrics.environmental,
      gap: metrics.gap,
      gap_ratio: metrics.gap_ratio,
      entropy: metrics.entropy,
      high_entropy: metrics.entropy > @entropy_threshold,
      recommendations: generate_recommendations(metrics)
    }
  end
  
  # Private Functions - MCP Discovery
  
  defp discover_mcp_capabilities(category, metrics) do
    # Query MCP server registry (simulated)
    available_servers = get_available_mcp_servers()
    
    # Filter by category if specified
    filtered = if category do
      Enum.filter(available_servers, fn server ->
        Enum.any?(@capability_categories[category] || [], fn tag ->
          tag in server.tags
        end)
      end)
    else
      available_servers
    end
    
    # Score servers based on variety gap
    scored_servers = Enum.map(filtered, fn server ->
      score = calculate_capability_score(server, metrics)
      Map.put(server, :variety_score, score)
    end)
    |> Enum.sort_by(& &1.variety_score, :desc)
    
    # Return top candidates
    scored_servers
    |> Enum.take(10)
    |> Enum.map(fn server ->
      {server.id, server}
    end)
    |> Map.new()
  end
  
  defp get_available_mcp_servers do
    # In production, query actual MCP registry
    # This is demonstration data
    [
      %{
        id: "postgresql-mcp",
        name: "PostgreSQL MCP",
        tags: ["database", "sql", "analytics"],
        capabilities: [:query, :transaction, :analytics],
        variety_amplification: 1.5
      },
      %{
        id: "llm-mcp",
        name: "LLM Integration MCP",
        tags: ["llm", "ai", "nlp"],
        capabilities: [:generation, :analysis, :embedding],
        variety_amplification: 2.0
      },
      %{
        id: "github-mcp",
        name: "GitHub MCP",
        tags: ["api", "integration", "development"],
        capabilities: [:repository, :issues, :actions],
        variety_amplification: 1.3
      },
      %{
        id: "monitoring-mcp",
        name: "Monitoring MCP",
        tags: ["monitoring", "alerts", "infrastructure"],
        capabilities: [:metrics, :logs, :alerts],
        variety_amplification: 1.2
      }
    ]
  end
  
  defp calculate_capability_score(server, metrics) do
    # Score based on how well the server addresses variety gap
    base_score = server.variety_amplification
    
    # Adjust for current needs
    gap_factor = if metrics.gap_ratio > @high_gap_threshold, do: 1.5, else: 1.0
    entropy_factor = if metrics.entropy > @entropy_threshold, do: 1.2, else: 1.0
    
    base_score * gap_factor * entropy_factor
  end
  
  defp install_mcp_capability(capability_id, state) do
    with {:ok, capability} <- Map.fetch(state.discovered_capabilities, capability_id),
         :ok <- ServerManager.discover_and_install(capability.name) do
      
      # Update variety after installation
      Process.send_after(self(), :periodic_variety_check, 5000)
      
      {:ok, %{
        capability: capability_id,
        installed_at: DateTime.utc_now(),
        expected_variety_increase: capability.variety_amplification
      }}
    else
      :error -> {:error, :capability_not_found}
      error -> error
    end
  end
  
  # Private Functions - Worker Management
  
  defp initialize_worker_pool do
    # Start with a basic worker pool
    1..4
    |> Enum.map(fn i ->
      worker = %{
        id: "worker_#{i}",
        type: :general,
        capacity: 1.0,
        current_load: 0.0
      }
      {worker.id, worker}
    end)
    |> Map.new()
  end
  
  defp adjust_worker_pool(pool, adjustment, metrics) do
    current_size = map_size(pool)
    
    case adjustment do
      {:scale_up, count} ->
        # Add new workers
        new_workers = (current_size + 1)..(current_size + count)
        |> Enum.map(fn i ->
          worker = create_specialized_worker(i, metrics)
          {worker.id, worker}
        end)
        |> Map.new()
        
        Map.merge(pool, new_workers)
        
      {:scale_down, count} ->
        # Remove least loaded workers
        workers_to_remove = pool
        |> Enum.sort_by(fn {_, w} -> w.current_load end)
        |> Enum.take(count)
        |> Enum.map(fn {id, _} -> id end)
        
        Map.drop(pool, workers_to_remove)
        
      {:optimize, _} ->
        # Rebalance worker types based on metrics
        optimize_worker_types(pool, metrics)
    end
  end
  
  defp create_specialized_worker(id, metrics) do
    # Create worker type based on current needs
    worker_type = cond do
      metrics.entropy > @entropy_threshold -> :adaptive
      metrics.gap_ratio > @high_gap_threshold -> :amplifier
      true -> :general
    end
    
    %{
      id: "worker_#{id}",
      type: worker_type,
      capacity: case worker_type do
        :adaptive -> 1.5
        :amplifier -> 2.0
        :general -> 1.0
      end,
      current_load: 0.0,
      created_at: DateTime.utc_now()
    }
  end
  
  defp optimize_worker_types(pool, metrics) do
    # Rebalance worker types based on current metrics
    total_workers = map_size(pool)
    
    # Calculate optimal distribution
    distribution = calculate_optimal_distribution(metrics, total_workers)
    
    # Transform existing workers
    pool
    |> Enum.with_index()
    |> Enum.map(fn {{id, worker}, idx} ->
      new_type = determine_worker_type(idx, distribution)
      {id, %{worker | type: new_type}}
    end)
    |> Map.new()
  end
  
  defp calculate_optimal_distribution(metrics, total_workers) do
    cond do
      metrics.gap_ratio > @critical_gap_threshold ->
        # Need maximum variety amplification
        %{
          amplifier: round(total_workers * 0.6),
          adaptive: round(total_workers * 0.3),
          general: round(total_workers * 0.1)
        }
        
      metrics.entropy > @entropy_threshold ->
        # Need adaptability
        %{
          amplifier: round(total_workers * 0.2),
          adaptive: round(total_workers * 0.6),
          general: round(total_workers * 0.2)
        }
        
      true ->
        # Balanced distribution
        %{
          amplifier: round(total_workers * 0.3),
          adaptive: round(total_workers * 0.3),
          general: round(total_workers * 0.4)
        }
    end
  end
  
  defp determine_worker_type(index, distribution) do
    amplifier_count = distribution.amplifier
    adaptive_count = distribution.adaptive
    
    cond do
      index < amplifier_count -> :amplifier
      index < amplifier_count + adaptive_count -> :adaptive
      true -> :general
    end
  end
  
  # Private Functions - Autonomous Actions
  
  defp take_autonomous_action(metrics, state) do
    cond do
      metrics.gap_ratio > @critical_gap_threshold ->
        handle_critical_gap(metrics, state)
        
      metrics.gap_ratio > @high_gap_threshold ->
        handle_high_gap(metrics, state)
        
      metrics.entropy > @entropy_threshold ->
        handle_high_entropy(metrics, state)
        
      true ->
        %{state | current_metrics: metrics}
    end
  end
  
  defp handle_critical_gap(metrics, state) do
    Logger.error("Critical variety gap detected: #{metrics.gap_ratio}")
    
    # Immediate actions:
    # 1. Scale up workers
    {:ok, new_size} = scale_workers({:scale_up, 3})
    
    # 2. Install highest scored capability
    case state.discovered_capabilities 
         |> Enum.max_by(fn {_, cap} -> cap[:variety_score] || 0 end, fn -> nil end) do
      {id, _} ->
        Task.start(fn -> install_capability(id) end)
      nil ->
        # Trigger immediate discovery
        send(self(), :discover_new_capabilities)
    end
    
    # 3. Alert management system
    Phoenix.PubSub.broadcast(Vsmcp.PubSub, "management_alerts", {
      :critical_variety_gap,
      metrics
    })
    
    action = %{
      type: :critical_gap_response,
      gap_ratio: metrics.gap_ratio,
      actions_taken: [:scale_workers, :install_capability, :alert_management],
      timestamp: DateTime.utc_now()
    }
    
    %{state | 
      current_metrics: metrics,
      action_log: [action | state.action_log]
    }
  end
  
  defp handle_high_gap(metrics, state) do
    Logger.warn("High variety gap detected: #{metrics.gap_ratio}")
    
    # Planned actions:
    # 1. Moderate scaling
    {:ok, _} = scale_workers({:scale_up, 1})
    
    # 2. Schedule capability evaluation
    Process.send_after(self(), :evaluate_capabilities, 60_000)
    
    action = %{
      type: :high_gap_response,
      gap_ratio: metrics.gap_ratio,
      actions_taken: [:moderate_scale, :schedule_evaluation],
      timestamp: DateTime.utc_now()
    }
    
    %{state | 
      current_metrics: metrics,
      action_log: [action | state.action_log]
    }
  end
  
  defp handle_high_entropy(metrics, state) do
    Logger.info("High system entropy detected: #{metrics.entropy}")
    
    # Optimize for adaptability
    new_pool = adjust_worker_pool(state.worker_pool, {:optimize, metrics}, metrics)
    
    action = %{
      type: :high_entropy_response,
      entropy: metrics.entropy,
      actions_taken: [:optimize_workers],
      timestamp: DateTime.utc_now()
    }
    
    %{state | 
      current_metrics: metrics,
      worker_pool: new_pool,
      action_log: [action | state.action_log]
    }
  end
  
  defp discover_and_evaluate_capabilities(metrics) do
    # Background task to discover and evaluate new capabilities
    categories = prioritize_capability_categories(metrics)
    
    Enum.each(categories, fn category ->
      case discover_capabilities(category) do
        {:ok, capabilities} ->
          Logger.info("Discovered #{map_size(capabilities)} capabilities in #{category}")
        error ->
          Logger.error("Failed to discover capabilities: #{inspect(error)}")
      end
    end)
  end
  
  defp prioritize_capability_categories(metrics) do
    # Prioritize categories based on current needs
    cond do
      metrics.gap_ratio > @critical_gap_threshold ->
        [:ai_ml, :data_processing, :infrastructure]
        
      metrics.entropy > @entropy_threshold ->
        [:integration, :ai_ml, :infrastructure]
        
      true ->
        [:data_processing, :integration, :security]
    end
  end
  
  defp generate_recommendations(metrics) do
    recommendations = []
    
    # Variety gap recommendations
    recommendations = if metrics.gap_ratio > @high_gap_threshold do
      [
        %{
          type: :variety_gap,
          severity: :high,
          action: "Install variety amplification capabilities",
          details: "Gap ratio: #{Float.round(metrics.gap_ratio, 2)}"
        } | recommendations
      ]
    else
      recommendations
    end
    
    # Entropy recommendations
    recommendations = if metrics.entropy > @entropy_threshold do
      [
        %{
          type: :high_entropy,
          severity: :medium,
          action: "Increase adaptive capacity",
          details: "System entropy: #{Float.round(metrics.entropy, 2)}"
        } | recommendations
      ]
    else
      recommendations
    end
    
    # Worker scaling recommendations
    recommendations = if metrics.gap_ratio > 0.3 do
      [
        %{
          type: :worker_scaling,
          severity: :medium,
          action: "Scale worker pool by #{round(metrics.gap_ratio * 10)}",
          details: "Current operational variety insufficient"
        } | recommendations
      ]
    else
      recommendations
    end
    
    recommendations
  end
end