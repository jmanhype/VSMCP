# AMQP Nervous System Demo
# 
# This demonstrates how the VSM systems communicate through the AMQP nervous system.
# Run with: mix run examples/amqp_nervous_system_demo.exs

defmodule AMQPNervousSystemDemo do
  alias Vsmcp.AMQP.NervousSystem
  
  def run do
    IO.puts "\n🧠 VSM AMQP Nervous System Demo\n"
    
    # Ensure RabbitMQ is running
    IO.puts "⚡ Note: This demo requires RabbitMQ to be running locally."
    IO.puts "   Start with: docker run -d -p 5672:5672 -p 15672:15672 rabbitmq:3-management\n"
    
    # Wait for system to initialize
    Process.sleep(2000)
    
    demonstrate_command_channel()
    demonstrate_audit_channel()
    demonstrate_algedonic_channel()
    demonstrate_horizontal_channel()
    demonstrate_intel_channel()
    demonstrate_coordination()
    
    IO.puts "\n✅ Demo complete!\n"
  end
  
  defp demonstrate_command_channel do
    IO.puts "📡 Command Channel Demo"
    IO.puts "   System 5 → System 3: Policy update"
    
    NervousSystem.send_command(:system5, :system3, %{
      type: "policy_update",
      policy: "audit_frequency",
      value: "every_30_minutes",
      effective_date: DateTime.utc_now()
    }, :urgent)
    
    IO.puts "   ✓ Policy command sent\n"
    Process.sleep(500)
  end
  
  defp demonstrate_audit_channel do
    IO.puts "📊 Audit Channel Demo"
    IO.puts "   System 1 → Audit: Operational metrics"
    
    NervousSystem.send_audit(:system1, %{
      unit: "production_unit_a",
      metrics: %{
        throughput: 1500,
        error_rate: 0.02,
        response_time: 120,
        resource_usage: 0.75
      },
      timestamp: DateTime.utc_now(),
      status: "healthy"
    })
    
    IO.puts "   ✓ Audit data broadcasted\n"
    Process.sleep(500)
  end
  
  defp demonstrate_algedonic_channel do
    IO.puts "🚨 Algedonic Channel Demo"
    IO.puts "   System 1 → System 5: Critical resource alert"
    
    NervousSystem.send_algedonic(:system1, :system5, %{
      type: "resource_critical",
      intensity: 200,
      resource: "memory",
      current_usage: 95,
      threshold_exceeded: true,
      unit: "production_unit_b"
    })
    
    IO.puts "   ✓ Emergency signal sent (bypassing hierarchy)\n"
    Process.sleep(500)
  end
  
  defp demonstrate_horizontal_channel do
    IO.puts "🔄 Horizontal Channel Demo"
    IO.puts "   Unit A ↔ Unit B: Load balancing"
    
    NervousSystem.send_horizontal("unit_a", "region_1", "load_transfer", %{
      current_load: 85,
      transfer_available: 35,
      accepting_transfers: false,
      reason: "high_load"
    })
    
    NervousSystem.send_horizontal("unit_b", "region_1", "load_transfer", %{
      current_load: 45,
      transfer_available: 0,
      accepting_transfers: true,
      capacity_available: 55
    })
    
    IO.puts "   ✓ Peer-to-peer coordination messages sent\n"
    Process.sleep(500)
  end
  
  defp demonstrate_intel_channel do
    IO.puts "🔍 Intelligence Channel Demo"
    IO.puts "   System 4 → System 5: Market opportunity"
    
    NervousSystem.send_intel("market_scanner", "opportunity", :urgent, %{
      market: "renewable_energy",
      opportunity_type: "partnership",
      potential_partner: "TechCorp",
      estimated_value: 5_000_000,
      confidence: 0.85,
      time_window: "6_months",
      competitive_advantage: "first_mover"
    })
    
    IO.puts "   ✓ Strategic intelligence transmitted\n"
    Process.sleep(500)
  end
  
  defp demonstrate_coordination do
    IO.puts "🎯 Multi-System Coordination Demo"
    IO.puts "   Emergency scenario: System-wide resource reallocation"
    
    # Step 1: System 4 detects upcoming demand spike
    IO.puts "\n   1️⃣ System 4 detects demand spike"
    NervousSystem.send_intel("demand_predictor", "forecast", :urgent, %{
      event: "demand_spike",
      magnitude: 2.5,
      eta_minutes: 30,
      affected_regions: ["region_1", "region_2"]
    })
    
    Process.sleep(300)
    
    # Step 2: System 5 issues emergency policy
    IO.puts "   2️⃣ System 5 activates surge protocol"
    NervousSystem.broadcast_status_request(:system5, [:system1, :system2, :system3], %{
      type: "activate_surge_protocol",
      priority: :emergency,
      duration_minutes: 60
    })
    
    Process.sleep(300)
    
    # Step 3: System 2 coordinates resources
    IO.puts "   3️⃣ System 2 coordinates resource allocation"
    result = NervousSystem.coordinate_resources(:system2, [
      {"unit_a", %{available: 40}},
      {"unit_b", %{available: 35}},
      {"unit_c", %{required: 50}},
      {"unit_d", %{required: 20}}
    ])
    
    case result do
      {:ok, allocations} ->
        IO.puts "   ✓ Resources successfully allocated: #{inspect(allocations)}"
      {:error, :insufficient_resources} ->
        IO.puts "   ⚠️  Insufficient resources - algedonic signal triggered"
    end
    
    Process.sleep(300)
    
    # Step 4: System 3 monitors compliance
    IO.puts "   4️⃣ System 3 monitors surge protocol compliance"
    NervousSystem.send_command(:system3, :system1, %{
      type: "compliance_check",
      protocol: "surge_protocol",
      check_points: ["resource_usage", "response_time", "error_rate"]
    })
    
    Process.sleep(300)
    
    # Step 5: Get system metrics
    IO.puts "\n   📊 Checking nervous system health..."
    
    case NervousSystem.get_metrics() do
      {:ok, metrics} ->
        IO.puts "   ✓ System metrics retrieved"
        IO.puts "     - Uptime: #{metrics.uptime_seconds}s"
        IO.puts "     - Overall health: #{metrics.overall_health}"
        
        Enum.each(metrics.channels, fn {channel, data} ->
          IO.puts "     - #{channel}: #{data.messages_sent} sent, #{data.messages_received} received"
        end)
        
      error ->
        IO.puts "   ⚠️  Could not retrieve metrics: #{inspect(error)}"
    end
  end
end

# Run the demo
AMQPNervousSystemDemo.run()