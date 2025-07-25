# Path: lib/vsmcp/mcp/capability_registry.ex
defmodule Vsmcp.MCP.CapabilityRegistry do
  @moduledoc """
  Registry for discovering, registering, and matching capabilities across VSM and MCP tools.
  Central hub for variety management and capability acquisition.
  """
  
  use GenServer
  require Logger
  
  alias Vsmcp.MCP.{Client, ToolRegistry}
  alias Vsmcp.Core.VarietyCalculator

  # Capability structure
  defmodule Capability do
    @enforce_keys [:id, :name, :type, :source]
    defstruct [:id, :name, :description, :type, :source, :interface, :metadata, :registered_at]
  end

  # Requirement structure
  defmodule Requirement do
    @enforce_keys [:id, :capability_type]
    defstruct [:id, :capability_type, :constraints, :priority, :context]
  end

  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  def register_capability(registry \\ __MODULE__, capability_def) do
    GenServer.call(registry, {:register_capability, capability_def})
  end

  def discover_capabilities(registry \\ __MODULE__, requirement) do
    GenServer.call(registry, {:discover_capabilities, requirement})
  end

  def match_capabilities(registry \\ __MODULE__, requirements) do
    GenServer.call(registry, {:match_capabilities, requirements})
  end

  def list_capabilities(registry \\ __MODULE__, filters \\ %{}) do
    GenServer.call(registry, {:list_capabilities, filters})
  end

  def acquire_capability(registry \\ __MODULE__, capability_id) do
    GenServer.call(registry, {:acquire_capability, capability_id}, 60_000)
  end

  def calculate_variety_gap(registry \\ __MODULE__) do
    GenServer.call(registry, :calculate_variety_gap)
  end

  # Server Callbacks
  
  @impl true
  def init(opts) do
    client = opts[:client] || Client
    tool_registry = opts[:tool_registry] || ToolRegistry
    
    # Schedule periodic capability discovery
    schedule_discovery()
    
    {:ok, %{
      capabilities: %{},
      requirements: %{},
      acquisitions: %{},
      client: client,
      tool_registry: tool_registry,
      discovery_interval: opts[:discovery_interval] || 300_000, # 5 minutes
      metrics: %{
        registered: 0,
        discovered: 0,
        acquired: 0,
        gaps_identified: 0
      }
    }}
  end

  @impl true
  def handle_call({:register_capability, cap_def}, _from, state) do
    capability = create_capability(cap_def)
    
    new_capabilities = Map.put(state.capabilities, capability.id, capability)
    new_metrics = %{state.metrics | registered: state.metrics.registered + 1}
    
    # Register with local tool registry if it's a local capability
    if capability.source.type == :local do
      register_local_tool(state.tool_registry, capability)
    end
    
    Logger.info("Registered capability: #{capability.name} (#{capability.id})")
    
    {:reply, {:ok, capability.id}, %{state | capabilities: new_capabilities, metrics: new_metrics}}
  end

  @impl true
  def handle_call({:discover_capabilities, requirement}, _from, state) do
    # Search local capabilities
    local_matches = search_local_capabilities(state.capabilities, requirement)
    
    # Search external MCP servers
    external_matches = search_external_capabilities(state.client, requirement)
    
    all_matches = local_matches ++ external_matches
    |> Enum.sort_by(&score_capability(&1, requirement), :desc)
    |> Enum.take(10) # Top 10 matches
    
    new_metrics = %{state.metrics | discovered: state.metrics.discovered + length(external_matches)}
    
    {:reply, {:ok, all_matches}, %{state | metrics: new_metrics}}
  end

  @impl true
  def handle_call({:match_capabilities, requirements}, _from, state) do
    # Match multiple requirements to available capabilities
    matches = Enum.map(requirements, fn req ->
      {:ok, caps} = handle_call({:discover_capabilities, req}, nil, state)
      {req.id, elem(caps, 1)}
    end)
    |> Map.new()
    
    # Identify gaps
    gaps = Enum.filter(requirements, fn req ->
      matched = Map.get(matches, req.id, [])
      Enum.empty?(matched) || !sufficient_match?(matched, req)
    end)
    
    result = %{
      matches: matches,
      gaps: gaps,
      coverage: calculate_coverage(requirements, matches)
    }
    
    new_metrics = if length(gaps) > 0 do
      %{state.metrics | gaps_identified: state.metrics.gaps_identified + length(gaps)}
    else
      state.metrics
    end
    
    {:reply, {:ok, result}, %{state | metrics: new_metrics}}
  end

  @impl true
  def handle_call({:list_capabilities, filters}, _from, state) do
    filtered = state.capabilities
    |> Map.values()
    |> apply_filters(filters)
    
    {:reply, filtered, state}
  end

  @impl true
  def handle_call({:acquire_capability, capability_id}, _from, state) do
    case Map.get(state.capabilities, capability_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
        
      %{source: %{type: :local}} ->
        {:reply, {:ok, :already_available}, state}
        
      capability ->
        case acquire_external_capability(capability, state) do
          {:ok, acquisition} ->
            new_acquisitions = Map.put(state.acquisitions, capability_id, acquisition)
            new_metrics = %{state.metrics | acquired: state.metrics.acquired + 1}
            
            {:reply, {:ok, acquisition}, %{state | acquisitions: new_acquisitions, metrics: new_metrics}}
            
          error ->
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call(:calculate_variety_gap, _from, state) do
    # Get current VSM variety
    {:ok, vsm_variety} = VarietyCalculator.calculate_system_variety()
    
    # Get available variety from capabilities
    available_variety = calculate_available_variety(state.capabilities)
    
    # Get required variety from environment
    required_variety = estimate_required_variety(state)
    
    gap = %{
      current: vsm_variety,
      available: available_variety,
      required: required_variety,
      gap: required_variety - vsm_variety,
      potential: available_variety - vsm_variety,
      recommendations: generate_recommendations(vsm_variety, available_variety, required_variety)
    }
    
    {:reply, {:ok, gap}, state}
  end

  @impl true
  def handle_info(:discover_capabilities, state) do
    # Periodic capability discovery
    Task.start_link(fn -> 
      discover_new_capabilities(state)
    end)
    
    schedule_discovery()
    {:noreply, state}
  end

  # Private Functions
  
  defp create_capability(cap_def) do
    %Capability{
      id: generate_capability_id(cap_def),
      name: cap_def.name,
      description: cap_def[:description],
      type: cap_def.type,
      source: cap_def.source,
      interface: cap_def[:interface] || %{},
      metadata: cap_def[:metadata] || %{},
      registered_at: DateTime.utc_now()
    }
  end

  defp generate_capability_id(cap_def) do
    "cap_#{cap_def.type}_#{:erlang.phash2(cap_def)}"
  end

  defp register_local_tool(tool_registry, capability) do
    tool_def = %{
      name: "capability.#{capability.id}",
      description: capability.description || "Capability: #{capability.name}",
      handler: capability.interface[:handler] || fn args -> {:ok, args} end,
      inputSchema: capability.interface[:schema]
    }
    
    ToolRegistry.register_tool(tool_registry, tool_def)
  end

  defp search_local_capabilities(capabilities, requirement) do
    capabilities
    |> Map.values()
    |> Enum.filter(fn cap ->
      matches_requirement?(cap, requirement)
    end)
    |> Enum.map(fn cap ->
      %{capability: cap, score: score_capability(cap, requirement), source: :local}
    end)
  end

  defp search_external_capabilities(client, requirement) do
    # Discover MCP servers that might have the capability
    case Client.discover_servers(client, requirement.capability_type) do
      {:ok, servers} ->
        Enum.flat_map(servers, fn server ->
          # Get tools from each server
          case connect_and_list_tools(client, server) do
            {:ok, tools} ->
              tools
              |> Enum.filter(fn tool ->
                tool_matches_requirement?(tool, requirement)
              end)
              |> Enum.map(fn tool ->
                %{
                  capability: %Capability{
                    id: "ext_#{server.name}_#{tool["name"]}",
                    name: tool["name"],
                    description: tool["description"],
                    type: requirement.capability_type,
                    source: %{type: :external, server: server},
                    interface: %{tool: tool},
                    registered_at: DateTime.utc_now()
                  },
                  score: score_tool(tool, requirement),
                  source: :external
                }
              end)
              
            _ -> []
          end
        end)
        
      _ -> []
    end
  end

  defp connect_and_list_tools(client, server) do
    # Try to connect and list tools, with caching
    case Client.connect(client, server) do
      {:ok, server_id} ->
        Client.list_tools(client, server_id)
      error ->
        error
    end
  end

  defp matches_requirement?(capability, requirement) do
    capability.type == requirement.capability_type &&
    satisfies_constraints?(capability, requirement.constraints || %{})
  end

  defp tool_matches_requirement?(tool, requirement) do
    # Match tool against requirement
    keywords = String.split(requirement.capability_type, "_")
    
    Enum.any?(keywords, fn keyword ->
      String.contains?(String.downcase(tool["name"]), keyword) ||
      String.contains?(String.downcase(tool["description"] || ""), keyword)
    end)
  end

  defp satisfies_constraints?(capability, constraints) do
    # Check if capability satisfies all constraints
    Enum.all?(constraints, fn {key, value} ->
      cap_value = get_in(capability.metadata, [key])
      matches_constraint?(cap_value, value)
    end)
  end

  defp matches_constraint?(nil, _), do: false
  defp matches_constraint?(value, constraint) when is_function(constraint, 1) do
    constraint.(value)
  end
  defp matches_constraint?(value, constraint), do: value == constraint

  defp score_capability(capability, requirement) do
    # Score based on various factors
    base_score = if capability.type == requirement.capability_type, do: 100, else: 0
    
    # Bonus for priority
    priority_bonus = case requirement.priority do
      :critical -> 50
      :high -> 30
      :medium -> 10
      _ -> 0
    end
    
    # Bonus for local capabilities
    source_bonus = case capability.source.type do
      :local -> 20
      _ -> 0
    end
    
    base_score + priority_bonus + source_bonus
  end

  defp score_tool(tool, requirement) do
    # Simple scoring for external tools
    keywords = String.split(requirement.capability_type, "_")
    
    keyword_matches = Enum.count(keywords, fn keyword ->
      String.contains?(String.downcase(tool["name"]), keyword) ||
      String.contains?(String.downcase(tool["description"] || ""), keyword)
    end)
    
    keyword_matches * 25
  end

  defp sufficient_match?(matches, requirement) do
    # Check if matches are sufficient for requirement
    case requirement.priority do
      :critical -> length(matches) > 0 && hd(matches).score >= 100
      :high -> length(matches) > 0 && hd(matches).score >= 75
      _ -> length(matches) > 0
    end
  end

  defp calculate_coverage(requirements, matches) do
    total = length(requirements)
    covered = Enum.count(requirements, fn req ->
      matched = Map.get(matches, req.id, [])
      sufficient_match?(matched, req)
    end)
    
    if total > 0 do
      covered / total * 100
    else
      100.0
    end
  end

  defp apply_filters(capabilities, filters) do
    capabilities
    |> filter_by_type(filters[:type])
    |> filter_by_source(filters[:source])
    |> filter_by_metadata(filters[:metadata])
  end

  defp filter_by_type(capabilities, nil), do: capabilities
  defp filter_by_type(capabilities, type) do
    Enum.filter(capabilities, &(&1.type == type))
  end

  defp filter_by_source(capabilities, nil), do: capabilities
  defp filter_by_source(capabilities, source_type) do
    Enum.filter(capabilities, &(&1.source.type == source_type))
  end

  defp filter_by_metadata(capabilities, nil), do: capabilities
  defp filter_by_metadata(capabilities, metadata_filters) do
    Enum.filter(capabilities, fn cap ->
      Enum.all?(metadata_filters, fn {k, v} ->
        get_in(cap.metadata, [k]) == v
      end)
    end)
  end

  defp acquire_external_capability(capability, state) do
    server = capability.source.server
    
    # Connect to server
    case Client.connect(state.client, server) do
      {:ok, server_id} ->
        # Create local adapter
        adapter = create_capability_adapter(capability, server_id, state.client)
        
        # Register adapter as local tool
        tool_def = %{
          name: capability.name,
          description: "Adapter for #{capability.name}",
          handler: adapter,
          inputSchema: capability.interface[:tool]["inputSchema"]
        }
        
        ToolRegistry.register_tool(state.tool_registry, tool_def)
        
        {:ok, %{
          capability_id: capability.id,
          server_id: server_id,
          adapter_registered: true,
          timestamp: DateTime.utc_now()
        }}
        
      error ->
        error
    end
  end

  defp create_capability_adapter(capability, server_id, client) do
    tool_name = capability.interface[:tool]["name"]
    
    fn args ->
      Client.call_tool(client, server_id, tool_name, args)
    end
  end

  defp calculate_available_variety(capabilities) do
    # Simplified variety calculation
    capabilities
    |> Map.values()
    |> Enum.uniq_by(& &1.type)
    |> length()
    |> Kernel.*(10) # Each unique capability type adds 10 variety points
  end

  defp estimate_required_variety(state) do
    # Estimate based on recent gaps and requirements
    base_variety = 100
    gap_penalty = state.metrics.gaps_identified * 5
    
    base_variety + gap_penalty
  end

  defp generate_recommendations(current, available, required) do
    recommendations = []
    
    recommendations = if current < required do
      ["Acquire new capabilities to close variety gap" | recommendations]
    else
      recommendations
    end
    
    recommendations = if available > current do
      ["Integrate available capabilities from MCP servers" | recommendations]
    else
      recommendations
    end
    
    recommendations = if required > available do
      ["Discover new MCP servers for missing capabilities" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end

  defp discover_new_capabilities(state) do
    # Periodically discover new capabilities from MCP ecosystem
    Logger.info("Running periodic capability discovery")
    
    # Common capability types to search for
    capability_types = [
      "data_processing",
      "machine_learning", 
      "api_integration",
      "monitoring",
      "automation",
      "security",
      "analytics"
    ]
    
    Enum.each(capability_types, fn type ->
      requirement = %Requirement{
        id: "discovery_#{type}",
        capability_type: type,
        priority: :low
      }
      
      case search_external_capabilities(state.client, requirement) do
        [] -> :ok
        matches ->
          # Register discovered capabilities
          Enum.each(matches, fn match ->
            GenServer.cast(self(), {:register_discovered, match.capability})
          end)
      end
    end)
  end

  defp schedule_discovery do
    Process.send_after(self(), :discover_capabilities, 300_000) # 5 minutes
  end

  # Handle discovered capabilities
  @impl true
  def handle_cast({:register_discovered, capability}, state) do
    new_capabilities = Map.put(state.capabilities, capability.id, capability)
    {:noreply, %{state | capabilities: new_capabilities}}
  end
end