defmodule Vsmcp.Security.Integration do
  @moduledoc """
  Integration module that provides a unified interface for security
  and variety management features.
  """
  
  alias Vsmcp.Security.{Z3nZoneControl, NeuralBloomFilter, EventHandler}
  alias Vsmcp.Z3n.MriaWrapper
  alias Vsmcp.Variety.AutonomousManager
  
  @doc """
  Authenticate a user and generate a zone-based JWT token.
  """
  def authenticate(user_id, requested_zones, credentials) do
    # In production, verify credentials properly
    if verify_credentials(credentials) do
      # Check threat level of authentication attempt
      case NeuralBloomFilter.check_threat(credentials) do
        {true, confidence, _} when confidence > 0.7 ->
          {:error, :suspicious_activity}
          
        _ ->
          # Generate zone token
          Z3nZoneControl.generate_zone_token(user_id, requested_zones)
      end
    else
      {:error, :invalid_credentials}
    end
  end
  
  @doc """
  Perform a secure operation with zone validation.
  """
  def secure_operation(token, zone, operation, data) do
    # Validate zone access
    with {:ok, :granted} <- Z3nZoneControl.validate_access(token, zone, :execute),
         {false, _, _} <- NeuralBloomFilter.check_threat(data) do
      
      # Log operation
      MriaWrapper.write(:security_events, {
        :security_event,
        :erlang.unique_integer(),
        :operation_executed,
        :info,
        DateTime.utc_now(),
        %{zone: zone, operation: operation}
      })
      
      # Execute operation
      {:ok, execute_operation(operation, data)}
    else
      {:error, :access_denied} -> {:error, :zone_access_denied}
      {true, _, threat_info} -> {:error, {:threat_detected, threat_info}}
      error -> error
    end
  end
  
  @doc """
  Get current system security and variety status.
  """
  def system_status do
    # Get variety metrics
    {:ok, variety_analysis} = AutonomousManager.check_variety_gaps()
    
    # Get security statistics
    bloom_stats = NeuralBloomFilter.get_statistics()
    
    # Get zone hierarchy
    zone_hierarchy = Z3nZoneControl.get_zone_hierarchy()
    
    %{
      security: %{
        zones: zone_hierarchy,
        bloom_filter: bloom_stats,
        threat_detection_enabled: true
      },
      variety: variety_analysis,
      recommendations: AutonomousManager.get_recommendations(),
      timestamp: DateTime.utc_now()
    }
  end
  
  @doc """
  Enable full autonomous mode with security constraints.
  """
  def enable_autonomous_mode(token) do
    # Require viability zone access for autonomous mode
    case Z3nZoneControl.validate_access(token, :viability, :delegate) do
      {:ok, :granted} ->
        AutonomousManager.enable_autonomous_mode(true)
        {:ok, :autonomous_mode_enabled}
        
      _ ->
        {:error, :insufficient_permissions}
    end
  end
  
  @doc """
  Handle security incident with automatic response.
  """
  def handle_incident(incident_data) do
    # Classify incident
    incident_type = classify_incident(incident_data)
    
    # Delegate to appropriate handler
    case incident_type do
      :threat ->
        EventHandler.handle_threat(incident_data)
        
      :zone_violation ->
        EventHandler.handle_zone_violation(incident_data)
        
      :variety_alert ->
        EventHandler.handle_variety_alert(incident_data)
        
      _ ->
        {:error, :unknown_incident_type}
    end
  end
  
  @doc """
  Install new capability with security validation.
  """
  def install_capability(token, capability_id) do
    # Require management zone for capability installation
    with {:ok, :granted} <- Z3nZoneControl.validate_access(token, :management, :write),
         {:ok, capabilities} <- AutonomousManager.discover_capabilities(),
         true <- Map.has_key?(capabilities, capability_id) do
      
      # Check if capability is safe
      capability = capabilities[capability_id]
      if safe_capability?(capability) do
        AutonomousManager.install_capability(capability_id)
      else
        {:error, :capability_failed_security_check}
      end
    else
      {:error, :access_denied} -> {:error, :insufficient_permissions}
      false -> {:error, :capability_not_found}
      error -> error
    end
  end
  
  @doc """
  Query distributed tables with security filtering.
  """
  def secure_query(token, table, query_params) do
    # Determine required zone based on table
    required_zone = case table do
      :security_events -> :management
      :variety_gaps -> :operational
      :vsm_states -> :operational
      :mcp_capabilities -> :operational
      _ -> :public
    end
    
    case Z3nZoneControl.validate_access(token, required_zone, :read) do
      {:ok, :granted} ->
        # Add security filters to query
        filtered_query = add_security_filters(query_params, token)
        MriaWrapper.query(table, filtered_query)
        
      _ ->
        {:error, :access_denied}
    end
  end
  
  # Private Functions
  
  defp verify_credentials(_credentials) do
    # In production, implement proper credential verification
    true
  end
  
  defp execute_operation(operation, data) do
    # Execute the actual operation
    # This would call into the appropriate VSM system
    %{
      operation: operation,
      result: :success,
      data: data,
      executed_at: DateTime.utc_now()
    }
  end
  
  defp classify_incident(incident_data) do
    cond do
      incident_data[:threat_level] -> :threat
      incident_data[:zone_violation] -> :zone_violation
      incident_data[:variety_gap] -> :variety_alert
      true -> :unknown
    end
  end
  
  defp safe_capability?(capability) do
    # Security check for capabilities
    unsafe_tags = ["untrusted", "experimental", "deprecated"]
    
    !Enum.any?(capability[:tags] || [], fn tag ->
      tag in unsafe_tags
    end)
  end
  
  defp add_security_filters(query_params, token) do
    # Add zone-based filtering to queries
    # In production, parse token to get user's zones
    query_params
  end
end