#!/usr/bin/env elixir
# Path: examples/telegram_vsm_demo.exs

# Demo: Telegram Bot as S1 Operational Unit
# Following Stafford Beer's VSM principles

Mix.install([
  {:vsmcp, path: "./"}
])

defmodule TelegramVSMDemo do
  @moduledoc """
  Demonstrates proper VSM integration with Telegram as S1 operational unit.
  Shows correct variety flow: External → S1 → S2/S3/S4/S5
  """
  
  def run do
    IO.puts """
    ╔══════════════════════════════════════════════════════════════╗
    ║        Telegram VSM Integration Demo (Beer's Principles)      ║
    ╚══════════════════════════════════════════════════════════════╝
    """
    
    # Start the VSMCP application
    {:ok, _} = Application.ensure_all_started(:vsmcp)
    
    # Give systems time to initialize
    Process.sleep(3000)
    
    # Check if Telegram is running
    if Vsmcp.Interfaces.TelegramSupervisor.running?() do
      IO.puts "\n✅ Telegram bot is running!"
      demo_vsm_flow()
    else
      IO.puts "\n❌ Telegram bot not running. Set TELEGRAM_BOT_TOKEN environment variable."
      IO.puts "   export TELEGRAM_BOT_TOKEN=your_bot_token"
    end
  end
  
  defp demo_vsm_flow do
    IO.puts "\n📊 VSM Flow Demonstration"
    IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 1. Show S1 capabilities
    IO.puts "\n1️⃣ System 1 Operational Capabilities:"
    {:ok, s1_state} = Vsmcp.Systems.System1.status()
    
    s1_state.capabilities
    |> Map.keys()
    |> Enum.each(fn cap ->
      IO.puts "   • #{cap}"
    end)
    
    # 2. Simulate variety flow
    IO.puts "\n2️⃣ Variety Flow (Beer's Model):"
    IO.puts """
    
       External World (Telegram Users)
              ↓ (variety)
       ┌─────────────────┐
       │   System 1      │ ← Telegram bot lives here!
       │  (Operations)   │   - Processes messages
       │                 │   - Executes commands
       └────────┬────────┘   - Spawns sub-VSMs
                │
                ↓ (filtered variety)
       ┌─────────────────┐
       │   System 2      │ ← Coordinates between units
       │ (Coordination)  │   - Handles complex requests
       └────────┬────────┘   - Balances resources
                │
                ↓ (coordinated operations)
       ┌─────────────────┐
       │   System 3      │ ← Monitors performance
       │   (Control)     │   - Audits operations
       └────────┬────────┘   - Optimizes resources
                │
                ↓ (performance data)
       ┌─────────────────┐
       │   System 4      │ ← Scans Telegram trends
       │ (Intelligence)  │   - NOT handling messages!
       └────────┬────────┘   - Forecasts variety
                │
                ↓ (intelligence)
       ┌─────────────────┐
       │   System 5      │ ← Sets policies
       │   (Policy)      │   - Strategic decisions
       └─────────────────┘
    """
    
    # 3. Show algedonic channel
    IO.puts "\n3️⃣ Algedonic Channel (Emergency Bypass):"
    IO.puts "   Urgent Telegram messages → Direct to S5"
    IO.puts "   Keywords: urgent, emergency, critical, alert"
    
    # 4. Environmental scanning by S4
    IO.puts "\n4️⃣ System 4 Environmental Scanning:"
    
    # Simulate S4 scanning
    env_data = %{
      telegram_activity: "moderate",
      user_patterns: ["questions", "commands", "status_checks"],
      complexity_trend: "increasing"
    }
    
    {:ok, intelligence} = Vsmcp.Systems.System4.scan_environment(env_data)
    
    IO.puts "   Current Intelligence:"
    intelligence
    |> Enum.take(3)
    |> Enum.each(fn {key, value} ->
      IO.puts "   • #{key}: #{inspect(value)}"
    end)
    
    # 5. Recursive VSM spawning
    IO.puts "\n5️⃣ Recursive VSM Spawning:"
    IO.puts "   Telegram users can spawn sub-VSMs with: /spawn_vsm <name>"
    IO.puts "   Each sub-VSM is a complete VSM with its own S1-S5!"
    
    # 6. Show AMQP channels
    IO.puts "\n6️⃣ AMQP Nervous System Channels:"
    exchanges = Vsmcp.AMQP.Config.ExchangeConfig.exchanges()
    
    exchanges
    |> Enum.each(fn {channel, config} ->
      IO.puts "   • #{channel}: #{config.name} (#{config.type})"
    end)
    
    # 7. Monitor real-time activity
    IO.puts "\n7️⃣ Real-Time Monitoring:"
    IO.puts "   Monitoring Telegram activity for 10 seconds..."
    
    # Subscribe to AMQP channels for monitoring
    ref = make_ref()
    Phoenix.PubSub.subscribe(Vsmcp.PubSub, "vsm:events")
    
    # Monitor for 10 seconds
    monitor_activity(10_000)
    
    Phoenix.PubSub.unsubscribe(Vsmcp.PubSub, "vsm:events")
    
    IO.puts "\n✅ Demo Complete!"
    IO.puts "\nTo interact with the bot:"
    IO.puts "1. Open Telegram and search for your bot"
    IO.puts "2. Send messages - they enter through S1"
    IO.puts "3. Try commands: /status, /help, /spawn_vsm"
    IO.puts "4. Send 'urgent' messages to trigger algedonic signals"
  end
  
  defp monitor_activity(duration) do
    end_time = System.monotonic_time(:millisecond) + duration
    do_monitor(end_time, 0)
  end
  
  defp do_monitor(end_time, count) do
    now = System.monotonic_time(:millisecond)
    
    if now < end_time do
      receive do
        {:vsm_event, event} ->
          IO.puts "   📡 Event: #{inspect(event.type)} from #{event.source}"
          do_monitor(end_time, count + 1)
      after
        1000 ->
          remaining = div(end_time - now, 1000)
          IO.write("\r   ⏱️  Monitoring... #{remaining}s remaining (#{count} events)")
          do_monitor(end_time, count)
      end
    else
      IO.puts "\n   📊 Captured #{count} events"
    end
  end
end

# Run the demo
TelegramVSMDemo.run()