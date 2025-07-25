defmodule Vsmcp.AMQP.NervousSystem do
  @moduledoc """
  High-level API for interacting with the VSM AMQP nervous system.
  
  This module provides convenient functions for VSM systems to communicate
  through the nervous system channels without dealing with AMQP details.
  """
  
  alias Vsmcp.AMQP.{Producers.BaseProducer, ChannelMonitor}
  
  @doc """
  Send a command from one system to another.
  
  ## Examples
  
      # System 2 coordinating System 1 operations
      NervousSystem.send_command(:system2, :system1, %{
        type: "resource_allocation",
        resources: %{cpu: 50, memory: 2048},
        duration: 3600
      })
      
      # System 5 setting policy for System 3
      NervousSystem.send_command(:system5, :system3, %{
        type: "policy_update",
        policy: "audit_frequency",
        value: "hourly"
      }, :urgent)
  """
  def send_command(from, to, command, priority \\ :normal) do
    BaseProducer.send_command(from, to, command, priority)
  end
  
  @doc """
  Send audit data to the audit channel.
  
  ## Examples
  
      # System 1 reporting operational metrics
      NervousSystem.send_audit(:system1, %{
        metrics: %{
          throughput: 1000,
          error_rate: 0.01,
          response_time: 150
        },
        status: "healthy"
      })
  """
  def send_audit(system, audit_data) do
    BaseProducer.send_audit(system, audit_data)
  end
  
  @doc """
  Send an algedonic (pain/pleasure) signal.
  
  These signals bypass the hierarchy and go directly to higher systems.
  
  ## Examples
  
      # System 1 experiencing critical resource shortage
      NervousSystem.send_algedonic(:system1, :system5, %{
        type: "resource_exhaustion",
        intensity: 200,
        resource: "memory",
        current_usage: 95
      })
  """
  def send_algedonic(from, to, signal) do
    BaseProducer.send_algedonic(from, to, signal)
  end
  
  @doc """
  Send a message horizontally between System 1 units.
  
  ## Examples
  
      # Unit A sharing load information with peers
      NervousSystem.send_horizontal("unit_a", "region_1", "load_sharing", %{
        current_load: 75,
        available_capacity: 25,
        accepting_transfers: true
      })
  """
  def send_horizontal(from_unit, region, message_type, data) do
    BaseProducer.send_horizontal(from_unit, region, message_type, data)
  end
  
  @doc """
  Send intelligence data through the intel channel.
  
  ## Examples
  
      # System 4 reporting market intelligence
      NervousSystem.send_intel("market_scanner", "opportunity", :urgent, %{
        market: "emerging_tech",
        opportunity: "ai_integration",
        potential_value: 1_000_000,
        time_window: "3_months"
      })
  """
  def send_intel(source, intel_type, urgency, data) do
    BaseProducer.send_intel(source, intel_type, urgency, data)
  end
  
  @doc """
  Get current metrics for all channels.
  
  Returns throughput, error rates, and queue depths.
  """
  def get_metrics do
    ChannelMonitor.get_metrics()
  end
  
  @doc """
  Get health status of a specific channel.
  
  ## Examples
  
      NervousSystem.get_channel_health(:command)
      # => {:ok, :healthy}
  """
  def get_channel_health(channel_type) do
    ChannelMonitor.get_channel_status(channel_type)
  end
  
  @doc """
  Emergency broadcast to all systems.
  
  Sends an algedonic signal to all systems simultaneously.
  
  ## Examples
  
      # Critical system-wide alert
      NervousSystem.emergency_broadcast(:system3, %{
        type: "security_breach",
        intensity: 255,
        location: "data_store",
        action_required: "immediate_lockdown"
      })
  """
  def emergency_broadcast(from, signal) do
    systems = [:system1, :system2, :system3, :system4, :system5]
    |> Enum.reject(& &1 == from)
    
    Enum.each(systems, fn system ->
      send_algedonic(from, system, signal)
    end)
    
    :ok
  end
  
  @doc """
  Request status from multiple systems.
  
  Useful for System 3 audits or System 2 coordination.
  
  ## Examples
  
      # System 3 requesting compliance status
      NervousSystem.broadcast_status_request(:system3, [:system1, :system2], %{
        type: "compliance_check",
        check_id: "audit_2024_01"
      })
  """
  def broadcast_status_request(from, target_systems, request) do
    Enum.each(target_systems, fn system ->
      send_command(from, system, request)
    end)
    
    :ok
  end
  
  @doc """
  Coordinate resource allocation across multiple System 1 units.
  
  ## Examples
  
      # System 2 coordinating load balancing
      NervousSystem.coordinate_resources(:system2, [
        {"unit_a", %{available: 30}},
        {"unit_b", %{available: 50}},
        {"unit_c", %{required: 40}}
      ])
  """
  def coordinate_resources(coordinator, unit_resources) do
    # Calculate optimal allocation
    total_available = 
      unit_resources
      |> Enum.filter(fn {_, res} -> Map.has_key?(res, :available) end)
      |> Enum.map(fn {_, res} -> res.available end)
      |> Enum.sum()
    
    total_required = 
      unit_resources
      |> Enum.filter(fn {_, res} -> Map.has_key?(res, :required) end)
      |> Enum.map(fn {_, res} -> res.required end)
      |> Enum.sum()
    
    if total_available >= total_required do
      # Send allocation commands
      allocations = calculate_allocations(unit_resources, total_available, total_required)
      
      Enum.each(allocations, fn {unit, allocation} ->
        send_horizontal(coordinator, "all", "resource_allocation", %{
          target_unit: unit,
          allocation: allocation
        })
      end)
      
      {:ok, allocations}
    else
      # Insufficient resources, escalate to System 5
      send_algedonic(coordinator, :system5, %{
        type: "resource_shortage",
        intensity: 150,
        shortage: total_required - total_available,
        units_affected: length(unit_resources)
      })
      
      {:error, :insufficient_resources}
    end
  end
  
  # Private functions
  
  defp calculate_allocations(unit_resources, total_available, total_required) do
    # Simple proportional allocation algorithm
    units_needing = 
      unit_resources
      |> Enum.filter(fn {_, res} -> Map.has_key?(res, :required) end)
    
    units_providing = 
      unit_resources
      |> Enum.filter(fn {_, res} -> Map.has_key?(res, :available) end)
    
    # For now, just distribute evenly
    allocation_per_unit = div(total_required, length(units_needing))
    
    Enum.map(units_needing, fn {unit, _} ->
      {unit, %{allocated: allocation_per_unit}}
    end)
  end
end