defmodule Vsmcp.Interfaces.TelegramPoller do
  @moduledoc """
  Simple Telegram polling implementation that doesn't rely on ExGram's built-in polling.
  This directly polls Telegram API and forwards updates to the bot handler.
  """
  
  use GenServer
  require Logger
  
  @poll_timeout 30_000  # 30 seconds long polling
  @poll_interval 1_000  # 1 second between polls if timeout
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    token = opts[:token] || raise "Bot token required"
    
    # Get the latest update ID to start from
    initial_offset = case get_updates(token, -1) do
      {:ok, [update | _]} ->
        update["update_id"] + 1
      _ ->
        0
    end
    
    state = %{
      token: token,
      offset: initial_offset,
      polling: true
    }
    
    Logger.info("Starting Telegram poller with token configured")
    
    # Start polling immediately
    send(self(), :poll)
    
    {:ok, state}
  end
  
  @impl true
  def handle_info(:poll, %{polling: false} = state) do
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:poll, state) do
    Logger.debug("Polling for updates with offset: #{state.offset}")
    
    case get_updates(state.token, state.offset) do
      {:ok, updates} ->
        Logger.debug("Got #{length(updates)} updates")
        
        # Process updates
        new_offset = process_updates(updates, state.offset)
        
        # Continue polling
        send(self(), :poll)
        
        {:noreply, %{state | offset: new_offset}}
        
      {:error, reason} ->
        Logger.error("Failed to get updates: #{inspect(reason)}")
        
        # Retry after interval
        Process.send_after(self(), :poll, @poll_interval)
        
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_call(:stop_polling, _from, state) do
    {:reply, :ok, %{state | polling: false}}
  end
  
  @impl true
  def handle_call(:start_polling, _from, state) do
    send(self(), :poll)
    {:reply, :ok, %{state | polling: true}}
  end
  
  defp get_updates(token, offset) do
    url = "https://api.telegram.org/bot#{token}/getUpdates"
    
    params = %{
      offset: offset,
      timeout: div(@poll_timeout, 1000)  # Convert to seconds
    }
    
    case HTTPoison.get(url, [], params: params, recv_timeout: @poll_timeout + 5000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"ok" => true, "result" => updates}} ->
            {:ok, updates}
          {:ok, %{"ok" => false, "description" => desc}} ->
            {:error, {:telegram_error, desc}}
          {:error, reason} ->
            {:error, {:json_decode_error, reason}}
        end
        
      {:ok, %HTTPoison.Response{status_code: code}} ->
        {:error, {:http_error, code}}
        
      {:error, reason} ->
        {:error, {:request_error, reason}}
    end
  end
  
  defp process_updates([], offset), do: offset
  defp process_updates(updates, _offset) do
    Enum.each(updates, &process_update/1)
    
    # Get the highest update_id and add 1
    max_id = updates
    |> Enum.map(& &1["update_id"])
    |> Enum.max()
    
    max_id + 1
  end
  
  defp process_update(update) do
    Logger.debug("Processing update: #{inspect(update)}")
    
    # Convert to ExGram-compatible format
    context = build_context(update)
    
    cond do
      # Handle commands
      command = extract_command(update) ->
        handle_command(command, context)
        
      # Handle regular messages
      text = get_in(update, ["message", "text"]) ->
        handle_message(text, context)
        
      true ->
        Logger.debug("Ignoring non-text update")
    end
  end
  
  defp build_context(update) do
    %{
      update: update,
      bot_info: %{
        id: 7747520054,
        is_bot: true,
        first_name: "VSM Control Panel Bot",
        username: "vsmcp_bot"
      }
    }
  end
  
  defp extract_command(update) do
    case get_in(update, ["message", "text"]) do
      "/" <> command_text ->
        command_text
        |> String.split(" ", parts: 2)
        |> List.first()
        |> String.to_atom()
      _ ->
        nil
    end
  end
  
  defp handle_command(command, context) do
    Logger.info("Handling command: #{command}")
    
    case command do
      :help ->
        send_help_message(context)
        
      :status ->
        # Forward to TelegramBot GenServer
        send(Vsmcp.Interfaces.TelegramBot, {:telegram_command, :status, context})
        
      :spawn_vsm ->
        args = extract_command_args(context.update)
        send(Vsmcp.Interfaces.TelegramBot, {:telegram_command, :spawn_vsm, args, context})
        
      _ ->
        Logger.debug("Unknown command: #{command}")
    end
  end
  
  defp handle_message(text, context) do
    Logger.info("Handling message: #{text}")
    
    # Forward to TelegramBot GenServer
    telegram_update = %{
      message: context.update["message"]
    }
    
    send(Vsmcp.Interfaces.TelegramBot, {:telegram_update, telegram_update})
  end
  
  defp extract_command_args(update) do
    case get_in(update, ["message", "text"]) do
      "/" <> command_text ->
        command_text
        |> String.split(" ", parts: 2)
        |> Enum.at(1, "")
      _ ->
        ""
    end
  end
  
  defp send_help_message(context) do
    help_text = """
    📚 *VSM Telegram Bot Help*
    
    Available commands:
    
    /status - Show VSM system status
    /spawn_vsm <name> - Spawn a sub-VSM
    /help - Show this help message
    
    Regular messages are processed as operational variety through System 1.
    
    Urgent messages (containing "urgent", "emergency", etc.) trigger algedonic signals.
    """
    
    chat_id = get_in(context.update, ["message", "chat", "id"])
    token = Application.get_env(:vsmcp, :telegram_bot_token)
    
    if chat_id && token do
      # Send directly via HTTPoison for now
      url = "https://api.telegram.org/bot#{token}/sendMessage"
      body = Jason.encode!(%{
        chat_id: chat_id,
        text: help_text,
        parse_mode: "Markdown"
      })
      
      HTTPoison.post(url, body, [{"Content-Type", "application/json"}])
    end
  end
end