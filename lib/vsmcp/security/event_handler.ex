defmodule Vsmcp.Security.EventHandler do
  @moduledoc """
  Centralized security event handler that coordinates responses
  across all security components.
  """
  
  use GenServer
  require Logger
  
  alias Vsmcp.Security.{Z3nZoneControl, NeuralBloomFilter}
  alias Vsmcp.Z3n.MriaWrapper
  alias Vsmcp.Variety.AutonomousManager
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def handle_threat(threat_data) do
    GenServer.cast(__MODULE__, {:handle_threat, threat_data})
  end
  
  def handle_zone_violation(violation_data) do
    GenServer.cast(__MODULE__, {:handle_zone_violation, violation_data})
  end
  
  def handle_variety_alert(alert_data) do
    GenServer.cast(__MODULE__, {:handle_variety_alert, alert_data})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    # Subscribe to security events
    Phoenix.PubSub.subscribe(Vsmcp.PubSub, "security_events")
    Phoenix.PubSub.subscribe(Vsmcp.PubSub, "variety_alerts")
    
    # Subscribe to Z3n events
    MriaWrapper.subscribe_events([:security_events, :variety_gaps])
    
    {:ok, %{
      threat_count: 0,
      violation_count: 0,
      alert_count: 0,
      recent_events: :queue.new()
    }}
  end
  
  @impl true
  def handle_cast({:handle_threat, threat_data}, state) do
    Logger.warn("Security threat detected: #{inspect(threat_data)}")
    
    # 1. Check with Neural Bloom Filter
    {is_threat, confidence, threat_info} = NeuralBloomFilter.check_threat(threat_data)
    
    if is_threat do
      # 2. Log to distributed table
      MriaWrapper.write(:security_events, {
        :security_event,
        :erlang.unique_integer(),
        :threat_detected,
        threat_info[:type] || :unknown,
        DateTime.utc_now(),
        %{
          confidence: confidence,
          data: threat_data,
          info: threat_info
        }
      })
      
      # 3. Check zone access if applicable
      if threat_data[:token] do
        case Z3nZoneControl.validate_access(threat_data.token, :operational, :execute) do
          {:ok, :granted} ->
            Logger.info("Threat from authorized source, logging only")
          {:error, :access_denied} ->
            Logger.error("Threat from unauthorized source, blocking")
            # Take blocking action
        end
      end
      
      # 4. Trigger variety check - threats might indicate environmental change
      AutonomousManager.check_variety_gaps()
    end
    
    {:noreply, update_in(state.threat_count, &(&1 + 1))}
  end
  
  @impl true
  def handle_cast({:handle_zone_violation, violation_data}, state) do
    Logger.error("Zone violation detected: #{inspect(violation_data)}")
    
    # Log violation
    MriaWrapper.write(:security_events, {
      :security_event,
      :erlang.unique_integer(),
      :zone_violation,
      :critical,
      DateTime.utc_now(),
      violation_data
    })
    
    # Train Neural Bloom Filter on this pattern
    NeuralBloomFilter.train_pattern(violation_data, :unauthorized)
    
    {:noreply, update_in(state.violation_count, &(&1 + 1))}
  end
  
  @impl true
  def handle_cast({:handle_variety_alert, alert_data}, state) do
    Logger.info("Variety alert received: #{inspect(alert_data)}")
    
    # Variety alerts might require security adjustments
    if alert_data[:gap_ratio] > 0.7 do
      # Critical variety gap - might need to relax some security constraints
      Logger.warn("Critical variety gap - considering security policy adjustments")
      
      # Could implement temporary zone policy relaxation here
    end
    
    {:noreply, update_in(state.alert_count, &(&1 + 1))}
  end
  
  @impl true
  def handle_info({:z3n_event, event}, state) do
    # Handle events from MriaWrapper
    case event.type do
      :security_events ->
        handle_cast({:handle_threat, event.data}, state)
      :variety_gaps ->
        handle_cast({:handle_variety_alert, event.data}, state)
      _ ->
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info(msg, state) do
    Logger.debug("Received message: #{inspect(msg)}")
    {:noreply, state}
  end
end