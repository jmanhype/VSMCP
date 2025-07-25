# Path: lib/vsmcp/mcp/delegation.ex
defmodule Vsmcp.MCP.Delegation do
  @moduledoc """
  Delegation patterns for sub-VSM tool sharing.
  Enables hierarchical VSM structures to share capabilities through MCP.
  """
  
  use GenServer
  require Logger
  
  alias Vsmcp.MCP.{Server, Client, ToolRegistry, CapabilityRegistry}

  # Delegation structure
  defmodule DelegationRule do
    @enforce_keys [:id, :from_vsm, :to_vsm, :capability_pattern]
    defstruct [:id, :from_vsm, :to_vsm, :capability_pattern, :constraints, :transform, :audit_trail]
  end

  defmodule SubVSM do
    @enforce_keys [:id, :name, :level]
    defstruct [:id, :name, :level, :parent_id, :mcp_server, :capabilities, :metrics]
  end

  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  def register_sub_vsm(delegation \\ __MODULE__, vsm_def) do
    GenServer.call(delegation, {:register_sub_vsm, vsm_def})
  end

  def create_delegation_rule(delegation \\ __MODULE__, rule_def) do
    GenServer.call(delegation, {:create_delegation_rule, rule_def})
  end

  def delegate_capability(delegation \\ __MODULE__, capability_name, from_vsm, to_vsm) do
    GenServer.call(delegation, {:delegate_capability, capability_name, from_vsm, to_vsm})
  end

  def request_capability(delegation \\ __MODULE__, vsm_id, capability_name, params) do
    GenServer.call(delegation, {:request_capability, vsm_id, capability_name, params}, 30_000)
  end

  def list_delegations(delegation \\ __MODULE__, vsm_id \\ nil) do
    GenServer.call(delegation, {:list_delegations, vsm_id})
  end

  def get_vsm_hierarchy(delegation \\ __MODULE__) do
    GenServer.call(delegation, :get_vsm_hierarchy)
  end

  # Server Callbacks
  
  @impl true
  def init(opts) do
    server = opts[:server] || Server
    client = opts[:client] || Client
    tool_registry = opts[:tool_registry] || ToolRegistry
    capability_registry = opts[:capability_registry] || CapabilityRegistry
    
    # Register root VSM
    root_vsm = %SubVSM{
      id: "vsm_root",
      name: "Root VSM",
      level: 0,
      capabilities: []
    }
    
    {:ok, %{
      vsms: %{"vsm_root" => root_vsm},
      delegation_rules: %{},
      active_delegations: %{},
      server: server,
      client: client,
      tool_registry: tool_registry,
      capability_registry: capability_registry,
      metrics: %{
        vsms_registered: 1,
        rules_created: 0,
        delegations_active: 0,
        requests_processed: 0
      }
    }}
  end

  @impl true
  def handle_call({:register_sub_vsm, vsm_def}, _from, state) do
    sub_vsm = create_sub_vsm(vsm_def)
    
    # Create MCP server for the sub-VSM
    mcp_server = create_vsm_mcp_server(sub_vsm, state)
    sub_vsm = %{sub_vsm | mcp_server: mcp_server}
    
    # Register initial capabilities
    capabilities = discover_vsm_capabilities(sub_vsm, state)
    sub_vsm = %{sub_vsm | capabilities: capabilities}
    
    new_vsms = Map.put(state.vsms, sub_vsm.id, sub_vsm)
    new_metrics = %{state.metrics | vsms_registered: state.metrics.vsms_registered + 1}
    
    Logger.info("Registered sub-VSM: #{sub_vsm.name} at level #{sub_vsm.level}")
    
    {:reply, {:ok, sub_vsm.id}, %{state | vsms: new_vsms, metrics: new_metrics}}
  end

  @impl true
  def handle_call({:create_delegation_rule, rule_def}, _from, state) do
    rule = create_rule(rule_def)
    
    # Validate VSMs exist
    case validate_vsms(rule, state) do
      :ok ->
        # Apply rule to matching capabilities
        delegations = apply_delegation_rule(rule, state)
        
        new_rules = Map.put(state.delegation_rules, rule.id, rule)
        new_active = Map.merge(state.active_delegations, delegations)
        new_metrics = %{state.metrics | 
          rules_created: state.metrics.rules_created + 1,
          delegations_active: state.metrics.delegations_active + map_size(delegations)
        }
        
        {:reply, {:ok, rule.id}, %{state | 
          delegation_rules: new_rules,
          active_delegations: new_active,
          metrics: new_metrics
        }}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:delegate_capability, capability_name, from_vsm, to_vsm}, _from, state) do
    # Create specific delegation
    case {Map.get(state.vsms, from_vsm), Map.get(state.vsms, to_vsm)} do
      {nil, _} ->
        {:reply, {:error, {:vsm_not_found, from_vsm}}, state}
        
      {_, nil} ->
        {:reply, {:error, {:vsm_not_found, to_vsm}}, state}
        
      {from, to} ->
        # Check if capability exists in source VSM
        if capability_name in from.capabilities do
          delegation_id = create_delegation(capability_name, from, to, state)
          
          new_active = Map.put(state.active_delegations, delegation_id, %{
            capability: capability_name,
            from: from_vsm,
            to: to_vsm,
            created_at: DateTime.utc_now()
          })
          
          {:reply, {:ok, delegation_id}, %{state | active_delegations: new_active}}
        else
          {:reply, {:error, {:capability_not_found, capability_name}}, state}
        end
    end
  end

  @impl true
  def handle_call({:request_capability, vsm_id, capability_name, params}, _from, state) do
    case Map.get(state.vsms, vsm_id) do
      nil ->
        {:reply, {:error, {:vsm_not_found, vsm_id}}, state}
        
      vsm ->
        # Check local capabilities first
        if capability_name in vsm.capabilities do
          result = execute_local_capability(vsm, capability_name, params, state)
          update_request_metrics(state)
          {:reply, result, state}
        else
          # Check delegated capabilities
          case find_delegated_capability(vsm_id, capability_name, state) do
            {:ok, delegation} ->
              result = execute_delegated_capability(delegation, params, state)
              update_request_metrics(state)
              {:reply, result, state}
              
            :not_found ->
              # Try to acquire through variety acquisition
              case acquire_capability_for_vsm(vsm, capability_name, state) do
                {:ok, _} ->
                  # Retry with newly acquired capability
                  result = execute_local_capability(vsm, capability_name, params, state)
                  {:reply, result, state}
                  
                _ ->
                  {:reply, {:error, {:capability_not_available, capability_name}}, state}
              end
          end
        end
    end
  end

  @impl true
  def handle_call({:list_delegations, vsm_id}, _from, state) do
    delegations = if vsm_id do
      state.active_delegations
      |> Map.values()
      |> Enum.filter(fn del ->
        del.from == vsm_id || del.to == vsm_id
      end)
    else
      Map.values(state.active_delegations)
    end
    
    {:reply, delegations, state}
  end

  @impl true
  def handle_call(:get_vsm_hierarchy, _from, state) do
    hierarchy = build_hierarchy(state.vsms)
    {:reply, {:ok, hierarchy}, state}
  end

  # Private Functions
  
  defp create_sub_vsm(vsm_def) do
    %SubVSM{
      id: vsm_def[:id] || generate_vsm_id(vsm_def),
      name: vsm_def.name,
      level: vsm_def.level,
      parent_id: vsm_def[:parent_id] || determine_parent(vsm_def.level),
      capabilities: vsm_def[:capabilities] || [],
      metrics: %{
        requests: 0,
        delegations_received: 0,
        delegations_provided: 0
      }
    }
  end

  defp generate_vsm_id(vsm_def) do
    "vsm_#{vsm_def.level}_#{:erlang.phash2(vsm_def)}"
  end

  defp determine_parent(level) do
    case level do
      0 -> nil
      1 -> "vsm_root"
      _ -> "vsm_#{level - 1}_default"
    end
  end

  defp create_vsm_mcp_server(sub_vsm, state) do
    # Create a namespaced MCP server for the sub-VSM
    server_config = %{
      name: "#{sub_vsm.id}_mcp_server",
      transport: :internal, # Internal transport for sub-VSMs
      namespace: sub_vsm.id
    }
    
    {:ok, server_pid} = GenServer.start_link(Server, [
      name: String.to_atom(server_config.name),
      transport: server_config.transport
    ])
    
    server_config
  end

  defp discover_vsm_capabilities(sub_vsm, state) do
    # Discover capabilities based on VSM level and type
    base_capabilities = case sub_vsm.level do
      1 -> ["execute", "coordinate", "report"] # Operational units
      2 -> ["coordinate", "audit", "optimize"] # Coordination level
      3 -> ["control", "audit", "intervene"] # Control level
      4 -> ["scan", "predict", "adapt"] # Intelligence level
      5 -> ["policy", "identity", "balance"] # Policy level
      _ -> []
    end
    
    # Add level-specific capabilities
    prefixed = Enum.map(base_capabilities, fn cap ->
      "vsm_#{sub_vsm.id}_#{cap}"
    end)
    
    # Register capabilities
    Enum.each(prefixed, fn cap ->
      CapabilityRegistry.register_capability(state.capability_registry, %{
        name: cap,
        type: :vsm_operation,
        source: %{type: :sub_vsm, vsm_id: sub_vsm.id}
      })
    end)
    
    prefixed
  end

  defp create_rule(rule_def) do
    %DelegationRule{
      id: generate_rule_id(rule_def),
      from_vsm: rule_def.from_vsm,
      to_vsm: rule_def.to_vsm,
      capability_pattern: rule_def.capability_pattern,
      constraints: rule_def[:constraints] || %{},
      transform: rule_def[:transform],
      audit_trail: rule_def[:audit_trail] || true
    }
  end

  defp generate_rule_id(rule_def) do
    "rule_#{rule_def.from_vsm}_to_#{rule_def.to_vsm}_#{:erlang.phash2(rule_def)}"
  end

  defp validate_vsms(rule, state) do
    cond do
      !Map.has_key?(state.vsms, rule.from_vsm) ->
        {:error, {:vsm_not_found, rule.from_vsm}}
        
      !Map.has_key?(state.vsms, rule.to_vsm) ->
        {:error, {:vsm_not_found, rule.to_vsm}}
        
      true ->
        :ok
    end
  end

  defp apply_delegation_rule(rule, state) do
    from_vsm = Map.get(state.vsms, rule.from_vsm)
    
    # Find matching capabilities
    matching = from_vsm.capabilities
    |> Enum.filter(&matches_pattern?(&1, rule.capability_pattern))
    |> Enum.filter(&satisfies_constraints?(&1, rule.constraints))
    
    # Create delegations
    matching
    |> Enum.map(fn cap ->
      delegation_id = "del_#{rule.id}_#{cap}"
      {delegation_id, %{
        rule_id: rule.id,
        capability: cap,
        from: rule.from_vsm,
        to: rule.to_vsm,
        transform: rule.transform,
        created_at: DateTime.utc_now()
      }}
    end)
    |> Map.new()
  end

  defp matches_pattern?(capability, pattern) when is_binary(pattern) do
    # Simple pattern matching with wildcards
    regex = pattern
    |> String.replace("*", ".*")
    |> Regex.compile!()
    
    Regex.match?(regex, capability)
  end

  defp matches_pattern?(capability, pattern) when is_function(pattern, 1) do
    pattern.(capability)
  end

  defp satisfies_constraints?(_capability, constraints) when map_size(constraints) == 0, do: true
  defp satisfies_constraints?(capability, constraints) do
    # Check capability metadata against constraints
    # Simplified - would check actual capability metadata
    true
  end

  defp create_delegation(capability_name, from_vsm, to_vsm, state) do
    delegation_id = "del_direct_#{capability_name}_#{from_vsm.id}_#{to_vsm.id}"
    
    # Register delegation in target VSM's MCP server
    tool_def = %{
      name: "delegated_#{capability_name}",
      description: "Delegated from #{from_vsm.name}",
      handler: create_delegation_handler(capability_name, from_vsm.id, state),
      inputSchema: get_capability_schema(capability_name, state)
    }
    
    # Would register with target VSM's MCP server
    Logger.info("Created delegation: #{capability_name} from #{from_vsm.id} to #{to_vsm.id}")
    
    delegation_id
  end

  defp create_delegation_handler(capability_name, source_vsm_id, state) do
    fn params ->
      # Execute capability in source VSM
      request_capability(__MODULE__, source_vsm_id, capability_name, params)
    end
  end

  defp get_capability_schema(capability_name, state) do
    # Get schema from capability registry
    case CapabilityRegistry.list_capabilities(state.capability_registry, %{name: capability_name}) do
      [%{interface: %{schema: schema}}] -> schema
      _ -> %{type: "object"}
    end
  end

  defp execute_local_capability(vsm, capability_name, params, state) do
    # Execute capability within VSM's context
    case ToolRegistry.call_tool(state.tool_registry, capability_name, params) do
      {:ok, result} ->
        # Update VSM metrics
        update_vsm_metrics(vsm.id, :request_executed, state)
        {:ok, result}
        
      error ->
        error
    end
  end

  defp execute_delegated_capability(delegation, params, state) do
    # Apply transformation if defined
    transformed_params = if delegation[:transform] do
      delegation.transform.(params)
    else
      params
    end
    
    # Execute in source VSM
    result = request_capability(__MODULE__, delegation.from, delegation.capability, transformed_params)
    
    # Audit trail
    if delegation[:audit_trail] do
      log_delegation_execution(delegation, params, result)
    end
    
    # Update metrics
    update_vsm_metrics(delegation.to, :delegation_used, state)
    update_vsm_metrics(delegation.from, :delegation_provided, state)
    
    result
  end

  defp find_delegated_capability(vsm_id, capability_name, state) do
    delegation = state.active_delegations
    |> Map.values()
    |> Enum.find(fn del ->
      del.to == vsm_id && del.capability == capability_name
    end)
    
    if delegation do
      {:ok, delegation}
    else
      :not_found
    end
  end

  defp acquire_capability_for_vsm(vsm, capability_name, state) do
    # Try to acquire capability through variety acquisition
    requirement = %{
      id: "vsm_#{vsm.id}_req_#{capability_name}",
      capability_type: capability_name,
      priority: :high,
      context: %{vsm_level: vsm.level}
    }
    
    case CapabilityRegistry.discover_capabilities(state.capability_registry, requirement) do
      {:ok, [match | _]} ->
        # Acquire and delegate to VSM
        CapabilityRegistry.acquire_capability(state.capability_registry, match.capability.id)
        
      _ ->
        {:error, :no_capability_found}
    end
  end

  defp build_hierarchy(vsms) do
    # Build tree structure of VSMs
    root = Map.get(vsms, "vsm_root")
    
    build_node(root, vsms)
  end

  defp build_node(vsm, all_vsms) do
    children = all_vsms
    |> Map.values()
    |> Enum.filter(&(&1.parent_id == vsm.id))
    |> Enum.map(&build_node(&1, all_vsms))
    
    %{
      id: vsm.id,
      name: vsm.name,
      level: vsm.level,
      capabilities: vsm.capabilities,
      metrics: vsm.metrics,
      children: children
    }
  end

  defp update_request_metrics(state) do
    GenServer.cast(self(), :increment_requests)
  end

  defp update_vsm_metrics(vsm_id, metric_type, state) do
    GenServer.cast(self(), {:update_vsm_metrics, vsm_id, metric_type})
  end

  defp log_delegation_execution(delegation, params, result) do
    Logger.info("Delegation executed: #{delegation.capability} from #{delegation.from} to #{delegation.to}")
    # Would store in audit log
  end

  # Async updates
  @impl true
  def handle_cast(:increment_requests, state) do
    new_metrics = %{state.metrics | requests_processed: state.metrics.requests_processed + 1}
    {:noreply, %{state | metrics: new_metrics}}
  end

  @impl true
  def handle_cast({:update_vsm_metrics, vsm_id, metric_type}, state) do
    case Map.get(state.vsms, vsm_id) do
      nil -> {:noreply, state}
      vsm ->
        updated_metrics = case metric_type do
          :request_executed ->
            %{vsm.metrics | requests: vsm.metrics.requests + 1}
          :delegation_used ->
            %{vsm.metrics | delegations_received: vsm.metrics.delegations_received + 1}
          :delegation_provided ->
            %{vsm.metrics | delegations_provided: vsm.metrics.delegations_provided + 1}
        end
        
        updated_vsm = %{vsm | metrics: updated_metrics}
        new_vsms = Map.put(state.vsms, vsm_id, updated_vsm)
        
        {:noreply, %{state | vsms: new_vsms}}
    end
  end
end