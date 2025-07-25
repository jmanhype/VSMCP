#!/usr/bin/env elixir

# Manually start Telegram supervisor with proper configuration

IO.puts("\n🚀 Starting Telegram Bot Manually\n")

# Check current configuration
telegram_config = Application.get_env(:vsmcp, :telegram, [])
IO.puts("Current telegram config: #{inspect(telegram_config)}")

# Get the bot token from runtime config
bot_token = telegram_config[:bot_token] || System.get_env("TELEGRAM_BOT_TOKEN", "7747520054:AAFNts5iJn8mYZezAG9uQF2_slvuztEScZI")

if bot_token && bot_token != "" do
  IO.puts("✅ Bot token found: #{String.slice(bot_token, 0, 10)}...")
  
  # Update the configuration
  Application.put_env(:vsmcp, :telegram, bot_token: bot_token)
  Application.put_env(:ex_gram, :token, bot_token)
  
  # Check if supervisor is already running
  case Process.whereis(Vsmcp.Interfaces.TelegramSupervisor) do
    nil ->
      IO.puts("\n🔄 Starting TelegramSupervisor...")
      case Vsmcp.Interfaces.TelegramSupervisor.start_link([]) do
        {:ok, pid} ->
          IO.puts("✅ TelegramSupervisor started with PID: #{inspect(pid)}")
          
          # Wait a moment for children to start
          Process.sleep(2000)
          
          # Check children
          IO.puts("\n📋 Checking children...")
          children = Supervisor.which_children(Vsmcp.Interfaces.TelegramSupervisor)
          Enum.each(children, fn {id, child_pid, type, _modules} ->
            status = case child_pid do
              :undefined -> "❌ NOT STARTED"
              pid when is_pid(pid) -> "✅ RUNNING (#{inspect(pid)})"
              :restarting -> "🔄 RESTARTING"
              _ -> "❓ UNKNOWN"
            end
            IO.puts("   • #{inspect(id)}: #{status}")
          end)
          
        {:error, reason} ->
          IO.puts("❌ Failed to start TelegramSupervisor: #{inspect(reason)}")
      end
      
    pid ->
      IO.puts("ℹ️  TelegramSupervisor already running with PID: #{inspect(pid)}")
      
      # Restart it
      IO.puts("🔄 Restarting TelegramSupervisor...")
      Supervisor.stop(pid)
      Process.sleep(1000)
      
      case Vsmcp.Interfaces.TelegramSupervisor.start_link([]) do
        {:ok, new_pid} ->
          IO.puts("✅ TelegramSupervisor restarted with PID: #{inspect(new_pid)}")
        {:error, reason} ->
          IO.puts("❌ Failed to restart: #{inspect(reason)}")
      end
  end
else
  IO.puts("❌ No bot token configured!")
end

# Final check
IO.puts("\n🔍 Final status check...")
Process.sleep(2000)

processes = [
  Vsmcp.Interfaces.TelegramSupervisor,
  Vsmcp.Interfaces.TelegramBot.BotHandler,
  Vsmcp.Interfaces.TelegramBot,
  Vsmcp.Interfaces.TelegramBotSimple
]

Enum.each(processes, fn module ->
  case Process.whereis(module) do
    nil -> IO.puts("❌ #{module}: NOT RUNNING")
    pid -> 
      if Process.alive?(pid) do
        IO.puts("✅ #{module}: RUNNING (#{inspect(pid)})")
      else
        IO.puts("⚠️  #{module}: DEAD PROCESS")
      end
  end
end)