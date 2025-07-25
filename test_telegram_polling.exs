# Test script to verify Telegram polling configuration
require Logger

# Check if token is available
telegram_config = Application.get_env(:vsmcp, :telegram, [])
bot_token = telegram_config[:bot_token]

if bot_token && bot_token != "" do
  Logger.info("Bot token configured: #{String.slice(bot_token, 0..10)}...")
  
  # Check if the bot module has the required functions
  if function_exported?(Vsmcp.Interfaces.TelegramBotSimple, :bot, 0) do
    bot_config = Vsmcp.Interfaces.TelegramBotSimple.bot()
    Logger.info("Bot config: #{inspect(bot_config)}")
    
    # Try to start the bot
    case Vsmcp.Interfaces.TelegramBotSimple.start_link([]) do
      {:ok, pid} ->
        Logger.info("✅ Bot started successfully! PID: #{inspect(pid)}")
        Process.sleep(5000)
        
        # Check if it's still alive
        if Process.alive?(pid) do
          Logger.info("✅ Bot is still running after 5 seconds")
        else
          Logger.error("❌ Bot died after starting")
        end
        
      {:error, reason} ->
        Logger.error("❌ Failed to start bot: #{inspect(reason)}")
    end
  else
    Logger.error("❌ TelegramBotSimple doesn't export bot/0 function")
  end
else
  Logger.error("❌ No bot token configured")
end