#!/usr/bin/env elixir

# Analyze Telegram Bot Supervision Tree

IO.puts("\n🔍 Analyzing Telegram Bot Supervision Tree\n")

# 1. Check if TelegramSupervisor is running
IO.puts("1️⃣ Checking TelegramSupervisor process...")
case Process.whereis(Vsmcp.Interfaces.TelegramSupervisor) do
  nil ->
    IO.puts("❌ TelegramSupervisor is NOT running!")
  pid ->
    IO.puts("✅ TelegramSupervisor is running with PID: #{inspect(pid)}")
    
    # Check supervisor children
    IO.puts("\n2️⃣ Checking TelegramSupervisor children...")
    try do
      children = Supervisor.which_children(Vsmcp.Interfaces.TelegramSupervisor)
      IO.puts("📋 Children count: #{length(children)}")
      
      Enum.each(children, fn {id, child_pid, type, modules} ->
        status = case child_pid do
          :undefined -> "❌ NOT STARTED"
          pid when is_pid(pid) -> 
            if Process.alive?(pid) do
              "✅ RUNNING (#{inspect(pid)})"
            else
              "⚠️  DEAD PROCESS"
            end
          :restarting -> "🔄 RESTARTING"
          other -> "❓ UNKNOWN: #{inspect(other)}"
        end
        
        IO.puts("   • #{inspect(id)}: #{status}")
        IO.puts("     Type: #{type}, Modules: #{inspect(modules)}")
      end)
    rescue
      e ->
        IO.puts("❌ Error getting children: #{inspect(e)}")
    end
end

# 2. Check individual processes
IO.puts("\n3️⃣ Checking individual processes...")

processes = [
  {Vsmcp.Interfaces.TelegramBot.BotHandler, "BotHandler (circuit breaker)"},
  {Vsmcp.Interfaces.TelegramBot, "TelegramBot (message processor)"},
  {Vsmcp.Interfaces.TelegramBotSimple, "TelegramBotSimple (ExGram bot)"}
]

Enum.each(processes, fn {module, description} ->
  case Process.whereis(module) do
    nil ->
      IO.puts("❌ #{module} - #{description}: NOT RUNNING")
    pid ->
      if Process.alive?(pid) do
        IO.puts("✅ #{module} - #{description}: RUNNING (#{inspect(pid)})")
        
        # Get process info
        info = Process.info(pid, [:message_queue_len, :status, :current_function])
        IO.puts("     Queue: #{info[:message_queue_len]}, Status: #{info[:status]}")
      else
        IO.puts("⚠️  #{module} - #{description}: DEAD PROCESS")
      end
  end
end)

# 3. Check for ExGram Bot processes
IO.puts("\n4️⃣ Searching for ExGram Bot processes...")
all_processes = Process.list()
exgram_processes = Enum.filter(all_processes, fn pid ->
  case Process.info(pid, :registered_name) do
    {:registered_name, name} when is_atom(name) ->
      String.contains?(to_string(name), "ExGram") or 
      String.contains?(to_string(name), "Vsmcp.Interfaces.TelegramBotSimple")
    _ ->
      # Check dictionary for ExGram modules
      case Process.info(pid, :dictionary) do
        {:dictionary, dict} ->
          Enum.any?(dict, fn {k, v} ->
            (is_atom(k) and String.contains?(to_string(k), "ExGram")) or
            (is_atom(v) and String.contains?(to_string(v), "ExGram"))
          end)
        _ -> false
      end
  end
end)

IO.puts("Found #{length(exgram_processes)} ExGram-related processes:")
Enum.each(exgram_processes, fn pid ->
  info = Process.info(pid, [:registered_name, :current_function, :status])
  IO.puts("   • PID: #{inspect(pid)}")
  IO.puts("     Name: #{inspect(info[:registered_name])}")
  IO.puts("     Function: #{inspect(info[:current_function])}")
  IO.puts("     Status: #{inspect(info[:status])}")
end)

# 4. Check configuration
IO.puts("\n5️⃣ Checking Telegram configuration...")
telegram_config = Application.get_env(:vsmcp, :telegram, [])
bot_token = telegram_config[:bot_token]
ex_gram_token = Application.get_env(:ex_gram, :token)

case bot_token do
  nil -> IO.puts("❌ No bot token in :vsmcp, :telegram config")
  "" -> IO.puts("❌ Empty bot token in :vsmcp, :telegram config")
  token when is_binary(token) -> 
    IO.puts("✅ Bot token configured in :vsmcp, :telegram (length: #{String.length(token)})")
end

case ex_gram_token do
  nil -> IO.puts("❌ No bot token in :ex_gram, :token config")
  "" -> IO.puts("❌ Empty bot token in :ex_gram, :token config")
  token when is_binary(token) -> 
    IO.puts("✅ Bot token configured in :ex_gram, :token (length: #{String.length(token)})")
end

# 5. Check for crash reports
IO.puts("\n6️⃣ Checking for recent crashes...")
# This is simplified - in production you'd check actual logs
IO.puts("ℹ️  Check server.log and console output for crash reports")

# 6. Try to find why TelegramBotSimple isn't starting
IO.puts("\n7️⃣ Analyzing potential issues...")
if Process.whereis(Vsmcp.Interfaces.TelegramBotSimple) == nil do
  IO.puts("🔍 TelegramBotSimple is not running. Possible reasons:")
  IO.puts("   • ExGram.child_spec might be failing")
  IO.puts("   • Bot token might not be properly configured")
  IO.puts("   • Module compilation issues")
  IO.puts("   • Supervisor restart strategy might be preventing restart")
  
  # Check if module is loaded
  case Code.ensure_loaded(Vsmcp.Interfaces.TelegramBotSimple) do
    {:module, _} ->
      IO.puts("   ✅ Module is loaded correctly")
    {:error, reason} ->
      IO.puts("   ❌ Module loading error: #{inspect(reason)}")
  end
end

IO.puts("\n📊 Analysis complete!")