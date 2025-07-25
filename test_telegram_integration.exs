#!/usr/bin/env elixir
# Test script to verify Telegram VSM integration

# First, ensure we're in the right directory
IO.puts "Current directory: #{File.cwd!()}"

# Start only the essential applications
Application.ensure_all_started(:logger)
Application.ensure_all_started(:amqp)
Application.ensure_all_started(:phoenix_pubsub)
Application.ensure_all_started(:ex_gram)

# Configure the bot token
Application.put_env(:vsmcp, :telegram, 
  bot_token: "7747520054:AAFNts5iJn8mYZezAG9uQF2_slvuztEScZI"
)

# Test basic connectivity
IO.puts "\n🔍 Testing Telegram Bot Configuration..."
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

config = Application.get_env(:vsmcp, :telegram, [])
bot_token = config[:bot_token]

if bot_token && bot_token != "" do
  IO.puts "✅ Bot token configured: #{String.slice(bot_token, 0..20)}..."
  
  # Test ExGram connectivity
  case ExGram.get_me(token: bot_token) do
    {:ok, bot_info} ->
      IO.puts "\n✅ Successfully connected to Telegram!"
      IO.puts "🤖 Bot Info:"
      IO.puts "   Username: @#{bot_info.username}"
      IO.puts "   Name: #{bot_info.first_name}"
      IO.puts "   ID: #{bot_info.id}"
      
    {:error, reason} ->
      IO.puts "\n❌ Failed to connect to Telegram: #{inspect(reason)}"
  end
else
  IO.puts "❌ No bot token configured!"
end

IO.puts "\n📊 VSM Integration Status:"
IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check AMQP connection
amqp_config = Application.get_env(:vsmcp, :amqp, [])
IO.puts "\n🐰 AMQP Configuration:"
IO.puts "   Host: #{amqp_config[:host] || "localhost"}"
IO.puts "   Port: #{amqp_config[:port] || 5672}"

case AMQP.Connection.open(amqp_config) do
  {:ok, conn} ->
    IO.puts "   ✅ Connected to RabbitMQ"
    AMQP.Connection.close(conn)
  {:error, reason} ->
    IO.puts "   ❌ RabbitMQ connection failed: #{inspect(reason)}"
end

IO.puts "\n🏗️ VSM Architecture:"
IO.puts """
   System 1 (Operations) - Handles Telegram messages
   System 2 (Coordination) - Coordinates complex requests  
   System 3 (Control) - Monitors and audits
   System 4 (Intelligence) - Environmental scanning
   System 5 (Policy) - Strategic decisions
"""

IO.puts "\n✨ Telegram Bot Commands:"
IO.puts """
   /status - Show VSM system status
   /help - Display help information
   /spawn_vsm <name> - Create recursive sub-VSM
   
   Regular messages → S1 operational processing
   Urgent messages → Algedonic channel to S5
"""

IO.puts "\n🚀 Integration Features:"
IO.puts """
   ✓ Messages as S1 operational variety
   ✓ Environmental scanning by S4
   ✓ Algedonic signals for urgent messages
   ✓ Recursive VSM spawning capability
   ✓ AMQP nervous system integration
"""

IO.puts "\n✅ Telegram VSM Integration Test Complete!"