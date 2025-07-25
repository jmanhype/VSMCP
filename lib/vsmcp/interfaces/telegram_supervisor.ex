defmodule Vsmcp.Interfaces.TelegramSupervisor do
  @moduledoc """
  Supervisor for the Telegram Bot interface.
  Only starts if a bot token is configured.
  """
  use Supervisor
  require Logger
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    # Get telegram configuration
    telegram_config = Application.get_env(:vsmcp, :telegram, [])
    bot_token = telegram_config[:bot_token]
    
    children = 
      if bot_token && bot_token != "" do
        Logger.info("Starting Telegram bot interface with token configured")
        
        # Set the token in application env for ExGram to pick up
        Application.put_env(:vsmcp, :telegram_bot_token, bot_token)
        Application.put_env(:ex_gram, :token, bot_token)
        
        [
          # The BotHandler GenServer (circuit breaker and API bridge)
          {Vsmcp.Interfaces.TelegramBot.BotHandler, []},
          
          # The Telegram bot GenServer (processes messages)
          {Vsmcp.Interfaces.TelegramBot, [token: bot_token]},
          
          # Custom Telegram poller (replaces ExGram polling)
          {Vsmcp.Interfaces.TelegramPoller, [token: bot_token]}
        ]
      else
        Logger.info("Telegram bot token not configured, skipping Telegram interface")
        []
      end
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  @doc """
  Check if Telegram bot is configured and running
  """
  def running? do
    case Process.whereis(Vsmcp.Interfaces.TelegramBot) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end
  
  @doc """
  Get Telegram bot status
  """
  def status do
    if running?() do
      {:ok, GenServer.call(Vsmcp.Interfaces.TelegramBot, :status)}
    else
      {:error, :not_running}
    end
  end
end