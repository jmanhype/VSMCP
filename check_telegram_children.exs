#!/usr/bin/env elixir

# Check Telegram Supervisor Children in detail

IO.puts("\n🔍 Checking TelegramSupervisor children in detail...\n")

case Supervisor.which_children(Vsmcp.Interfaces.TelegramSupervisor) do
  children when is_list(children) ->
    IO.puts("Found #{length(children)} children:\n")
    
    Enum.each(children, fn child ->
      case child do
        {id, :undefined, type, modules} ->
          IO.puts("❌ Child not started:")
          IO.puts("   ID: #{inspect(id)}")
          IO.puts("   Type: #{type}")
          IO.puts("   Modules: #{inspect(modules)}")
          
        {id, :restarting, type, modules} ->
          IO.puts("🔄 Child restarting:")
          IO.puts("   ID: #{inspect(id)}")
          IO.puts("   Type: #{type}")
          IO.puts("   Modules: #{inspect(modules)}")
          
        {id, pid, type, modules} when is_pid(pid) ->
          status = if Process.alive?(pid), do: "✅ RUNNING", else: "⚠️  DEAD"
          IO.puts("#{status} Child:")
          IO.puts("   ID: #{inspect(id)}")
          IO.puts("   PID: #{inspect(pid)}")
          IO.puts("   Type: #{type}")
          IO.puts("   Modules: #{inspect(modules)}")
          
          # Get more info about the process
          if Process.alive?(pid) do
            info = Process.info(pid, [:registered_name, :current_function, :status, :message_queue_len])
            IO.puts("   Registered name: #{inspect(info[:registered_name])}")
            IO.puts("   Current function: #{inspect(info[:current_function])}")
            IO.puts("   Status: #{inspect(info[:status])}")
            IO.puts("   Message queue: #{info[:message_queue_len]}")
          end
          
        other ->
          IO.puts("❓ Unknown child format: #{inspect(other)}")
      end
      
      IO.puts("")
    end)
    
  error ->
    IO.puts("❌ Error getting children: #{inspect(error)}")
end

# Check if ExGram.Bot is properly defined
IO.puts("\n🔍 Checking ExGram.Bot availability...")
case Code.ensure_loaded(ExGram.Bot) do
  {:module, _} ->
    IO.puts("✅ ExGram.Bot module is loaded")
  {:error, reason} ->
    IO.puts("❌ ExGram.Bot not available: #{inspect(reason)}")
end

# Check if TelegramBotSimple uses ExGram.Bot correctly
IO.puts("\n🔍 Checking TelegramBotSimple module...")
case Code.ensure_loaded(Vsmcp.Interfaces.TelegramBotSimple) do
  {:module, module} ->
    IO.puts("✅ TelegramBotSimple module is loaded")
    
    # Check if it has the expected functions
    functions = module.__info__(:functions)
    IO.puts("   Functions count: #{length(functions)}")
    
    # Check for key ExGram.Bot functions
    expected = [:handle, :bot]
    Enum.each(expected, fn func ->
      if Keyword.has_key?(functions, func) do
        IO.puts("   ✅ Has function: #{func}/#{functions[func]}")
      else
        IO.puts("   ❌ Missing function: #{func}")
      end
    end)
    
  {:error, reason} ->
    IO.puts("❌ TelegramBotSimple not loaded: #{inspect(reason)}")
end

# Try to manually start the ExGram bot
IO.puts("\n🔍 Attempting to diagnose ExGram.child_spec issue...")
bot_config = [
  token: Application.get_env(:ex_gram, :token),
  method: :polling,
  bot: Vsmcp.Interfaces.TelegramBotSimple
]

IO.puts("Bot config: #{inspect(bot_config)}")

# Check if the token is set
if bot_config[:token] do
  IO.puts("✅ Token is configured")
  
  # Try to create the child spec
  try do
    spec = ExGram.child_spec(bot_config)
    IO.puts("✅ ExGram.child_spec succeeded:")
    IO.puts("   #{inspect(spec, pretty: true)}")
  rescue
    e ->
      IO.puts("❌ ExGram.child_spec failed: #{inspect(e)}")
      IO.puts("   Stack: #{inspect(__STACKTRACE__, pretty: true, limit: 3)}")
  end
else
  IO.puts("❌ No token configured for ExGram")
end