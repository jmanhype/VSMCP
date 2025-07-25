#!/usr/bin/env elixir

# Test Telegram bot startup with a test token

# Set a test bot token
test_token = "7747520054:AAFNts5iJn8mYZezAG9uQF2_slvuztEScZI"

IO.puts("Setting up Telegram bot configuration...")

# Set configuration
Application.put_env(:vsmcp, :telegram, [bot_token: test_token])
Application.put_env(:vsmcp, :telegram_bot_token, test_token)
Application.put_env(:ex_gram, :token, test_token)

IO.puts("Configuration set:")
IO.puts("  VSMCP telegram config: #{inspect(Application.get_env(:vsmcp, :telegram))}")
IO.puts("  ExGram token: #{inspect(Application.get_env(:ex_gram, :token))}")

# Try to start the supervisor manually
IO.puts("\nAttempting to start TelegramSupervisor...")

case Vsmcp.Interfaces.TelegramSupervisor.start_link([]) do
  {:ok, pid} ->
    IO.puts("✅ TelegramSupervisor started successfully: #{inspect(pid)}")
    
    # Wait a moment for children to start
    Process.sleep(1000)
    
    # Check children
    children = Supervisor.which_children(pid)
    IO.puts("\nSupervisor children:")
    Enum.each(children, fn {id, child, type, modules} ->
      IO.puts("  #{inspect(id)}: #{inspect(child)} (#{type})")
    end)
    
    # Check if bot processes are running
    IO.puts("\nChecking bot processes:")
    bot_simple = Process.whereis(Vsmcp.Interfaces.TelegramBotSimple)
    telegram_bot = Process.whereis(Vsmcp.Interfaces.TelegramBot)
    bot_handler = Process.whereis(Vsmcp.Interfaces.TelegramBot.BotHandler)
    
    IO.puts("  TelegramBotSimple: #{inspect(bot_simple)}")
    IO.puts("  TelegramBot: #{inspect(telegram_bot)}")
    IO.puts("  BotHandler: #{inspect(bot_handler)}")
    
    # Try to check ExGram registry again
    IO.puts("\nChecking ExGram registry:")
    try do
      registry_lookup = Registry.lookup(ExGram.Registry, Vsmcp.Interfaces.TelegramBotSimple)
      IO.puts("  Registry lookup: #{inspect(registry_lookup)}")
    rescue
      e ->
        IO.puts("  Registry error: #{inspect(e)}")
    end
    
  {:error, {:already_started, pid}} ->
    IO.puts("⚠️  TelegramSupervisor already running: #{inspect(pid)}")
    
  {:error, reason} ->
    IO.puts("❌ Failed to start TelegramSupervisor: #{inspect(reason)}")
end

IO.puts("\n=== Test Complete ===")