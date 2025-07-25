#!/usr/bin/env elixir

# Debug script to check Telegram bot configuration and status

IO.puts("\n=== Telegram Bot Debug Information ===\n")

# Check if TelegramBotSimple process is running
bot_simple_pid = Process.whereis(Vsmcp.Interfaces.TelegramBotSimple)
IO.puts("TelegramBotSimple process: #{inspect(bot_simple_pid)}")

# Check if TelegramBot GenServer is running
telegram_bot_pid = Process.whereis(Vsmcp.Interfaces.TelegramBot)
IO.puts("TelegramBot GenServer: #{inspect(telegram_bot_pid)}")

# Check if BotHandler is running
bot_handler_pid = Process.whereis(Vsmcp.Interfaces.TelegramBot.BotHandler)
IO.puts("BotHandler process: #{inspect(bot_handler_pid)}")

# Check if TelegramSupervisor is running
telegram_supervisor_pid = Process.whereis(Vsmcp.Interfaces.TelegramSupervisor)
IO.puts("TelegramSupervisor: #{inspect(telegram_supervisor_pid)}")

# Check configuration
IO.puts("\n=== Configuration ===")
telegram_config = Application.get_env(:vsmcp, :telegram, [])
IO.puts("VSMCP Telegram config: #{inspect(telegram_config)}")

ex_gram_token = Application.get_env(:ex_gram, :token)
IO.puts("ExGram token config: #{inspect(ex_gram_token)}")

vsmcp_bot_token = Application.get_env(:vsmcp, :telegram_bot_token)
IO.puts("VSMCP bot token: #{inspect(vsmcp_bot_token)}")

# Check ExGram registry
IO.puts("\n=== ExGram Registry ===")
try do
  ex_gram_registry = Registry.lookup(ExGram.Registry, Vsmcp.Interfaces.TelegramBotSimple)
  IO.puts("ExGram Registry lookup: #{inspect(ex_gram_registry)}")
rescue
  e ->
    IO.puts("ExGram Registry error: #{inspect(e)}")
end

# Check all registered processes
IO.puts("\n=== All Registered Processes (filtered) ===")
Process.registered()
|> Enum.filter(fn name -> 
  name_str = to_string(name)
  String.contains?(name_str, ["Telegram", "ExGram", "telegram", "Bot"])
end)
|> Enum.each(fn name ->
  pid = Process.whereis(name)
  IO.puts("#{inspect(name)}: #{inspect(pid)}")
end)

# Check supervisor children
if telegram_supervisor_pid do
  IO.puts("\n=== TelegramSupervisor Children ===")
  children = Supervisor.which_children(telegram_supervisor_pid)
  Enum.each(children, fn {id, child, type, modules} ->
    IO.puts("  #{inspect(id)}: #{inspect(child)} (#{type}) - #{inspect(modules)}")
  end)
end

# Try to check ExGram bot state
IO.puts("\n=== ExGram Bot State Check ===")
try do
  # Check if we can access the bot's state through GenServer
  if bot_simple_pid do
    state = :sys.get_state(bot_simple_pid)
    IO.puts("Bot state: #{inspect(state)}")
  else
    IO.puts("Bot process not found, cannot get state")
  end
rescue
  e ->
    IO.puts("Error getting bot state: #{inspect(e)}")
end

# Check ExGram application
IO.puts("\n=== ExGram Application ===")
ex_gram_loaded = Code.ensure_loaded?(ExGram)
IO.puts("ExGram loaded: #{ex_gram_loaded}")

if ex_gram_loaded do
  IO.puts("ExGram module available")
  # Try to check if ExGram.Bot behavior is loaded
  ex_gram_bot_loaded = Code.ensure_loaded?(ExGram.Bot)
  IO.puts("ExGram.Bot loaded: #{ex_gram_bot_loaded}")
end

IO.puts("\n=== Debug Complete ===\n")