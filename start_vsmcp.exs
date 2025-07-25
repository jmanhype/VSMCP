#!/usr/bin/env elixir
# Start VSMCP with Telegram Bot

# Set bot token if not already set
unless System.get_env("TELEGRAM_BOT_TOKEN") do
  System.put_env("TELEGRAM_BOT_TOKEN", "7747520054:AAFNts5iJn8mYZezAG9uQF2_slvuztEScZI")
end

IO.puts """
╔══════════════════════════════════════════════════════════════╗
║                    Starting VSMCP                             ║
║         Viable System Model with MCP & Telegram               ║
╚══════════════════════════════════════════════════════════════╝
"""

# Start the application
case Application.ensure_all_started(:vsmcp) do
  {:ok, apps} ->
    IO.puts "\n✅ VSMCP started successfully!"
    IO.puts "Started applications: #{inspect(apps)}"
    
    # Check subsystems
    IO.puts "\n🔍 Checking subsystems..."
    
    # AMQP Status
    case Vsmcp.AMQP.ConnectionPool.health_check() do
      :ok -> IO.puts "✅ AMQP: Connected to RabbitMQ"
      _ -> IO.puts "❌ AMQP: Not connected"
    end
    
    # Telegram Bot Status
    if Vsmcp.Interfaces.TelegramSupervisor.running?() do
      IO.puts "✅ Telegram Bot: Running"
      IO.puts "   Token: #{String.slice(System.get_env("TELEGRAM_BOT_TOKEN"), 0..20)}..."
    else
      IO.puts "❌ Telegram Bot: Not running"
    end
    
    # System Status
    IO.puts "\n📊 VSM Systems Status:"
    status = Vsmcp.status()
    IO.puts "   S1 (Operations): #{status.system_1[:status]}"
    IO.puts "   S2 (Coordination): #{status.system_2[:status]}"
    IO.puts "   S3 (Control): #{status.system_3[:status]}"
    IO.puts "   S4 (Intelligence): #{status.system_4[:status]}"
    IO.puts "   S5 (Policy): #{status.system_5[:status]}"
    
    IO.puts "\n🎯 VSMCP is ready!"
    IO.puts "\nAvailable operations:"
    IO.puts "  - Telegram bot: Send messages to your bot"
    IO.puts "  - MCP Server: Running on stdio transport"
    IO.puts "  - AMQP: All 5 VSM channels active"
    
    # Keep running
    IO.puts "\nPress Ctrl+C to stop..."
    Process.sleep(:infinity)
    
  {:error, {app, reason}} ->
    IO.puts "\n❌ Failed to start application: #{app}"
    IO.puts "Reason: #{inspect(reason)}"
    
    # Try to provide helpful troubleshooting
    case app do
      :vsmcp ->
        IO.puts "\nTroubleshooting:"
        IO.puts "1. Check RabbitMQ is running: sudo systemctl status rabbitmq-server"
        IO.puts "2. Check compilation: mix compile"
        IO.puts "3. Check dependencies: mix deps.get"
      _ ->
        IO.puts "\nDependency #{app} failed to start"
    end
end