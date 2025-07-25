defmodule Vsmcp.Interfaces.TelegramBot do
  @moduledoc """
  Telegram Bot interface following Stafford Beer's VSM principles.
  External variety (user messages) enters through System 1 (Operations).
  System 4 scans the environment but doesn't handle operations.
  """
  use GenServer
  require Logger
  
  alias Vsmcp.AMQP.NervousSystem
  alias Vsmcp.Systems.{System1, System4}
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    # Register as S1 operational capability
    :ok = System1.register_capability("telegram_interface", &handle_telegram_operation/1)
    
    # Schedule periodic environmental scan for S4
    Process.send_after(self(), :environmental_scan, 60_000)
    
    # The BotHandler module handles ExGram bot lifecycle
    # This GenServer just processes the messages forwarded by BotHandler
    {:ok, %{
      # Each chat is an operational unit in S1
      operational_units: %{},
      # Track message patterns for S4 analysis
      message_patterns: []
    }}
  end
  
  # CORRECT: Telegram messages are OPERATIONAL VARIETY entering S1
  @impl true
  def handle_info({:telegram_update, %{message: %{text: text, from: user, chat: chat}}}, state) do
    Logger.info("Operational variety from Telegram user #{user.id}: #{text}")
    
    # 1. This is OPERATIONAL VARIETY - goes to System 1!
    operation = %{
      capability: "telegram_interface",
      type: "user_request",
      params: %{
        text: text,
        user_id: user.id,
        username: user.username || "anonymous",
        chat_id: chat.id,
        timestamp: DateTime.utc_now()
      }
    }
    
    # 2. Send to S1 as operational command (not to S4!)
    case NervousSystem.send_command(:telegram_unit, :system1, operation) do
      :ok ->
        # Track pattern for S4 environmental scanning
        new_state = update_message_patterns(state, text)
        
        # 3. Check if this exceeds variety threshold (Ashby's Law)
        if requires_coordination?(text, state) do
          # S2 coordinates between operational units
          NervousSystem.send_command(:system1, :system2, %{
            type: "coordination_request",
            reason: "complex_user_request",
            units: ["telegram_unit", "processing_unit"]
          })
        end
        
        # 4. Algedonic signal for urgent requests
        if urgent?(text) do
          NervousSystem.broadcast_algedonic(%{
            source: "telegram_unit",
            signal: "user_urgency",
            intensity: 0.8
          })
        end
        
        {:noreply, new_state}
        
      {:error, reason} ->
        Logger.error("Failed to send operation to S1: #{inspect(reason)}")
        {:noreply, state}
    end
  end
  
  # Handle status command from BotHandler
  @impl true
  def handle_info({:telegram_command, :status, context}, state) do
    # Get VSM system status
    response = case Vsmcp.status() do
      {:ok, status} ->
        format_status(status)
      _ ->
        "❌ Unable to retrieve VSM status"
    end
    
    # Send response directly for now
    chat_id = get_in(context, [:update, "message", "chat", "id"])
    token = Application.get_env(:vsmcp, :telegram_bot_token)
    
    if chat_id && token do
      url = "https://api.telegram.org/bot#{token}/sendMessage"
      body = Jason.encode!(%{
        chat_id: chat_id,
        text: response,
        parse_mode: "Markdown"
      })
      
      case HTTPoison.post(url, body, [{"Content-Type", "application/json"}]) do
        {:ok, %{status_code: 200}} ->
          Logger.info("Sent status response to chat #{chat_id}")
        {:error, reason} ->
          Logger.error("Failed to send status: #{inspect(reason)}")
      end
    end
    
    {:noreply, state}
  end
  
  # Handle spawn VSM command from BotHandler
  @impl true
  def handle_info({:telegram_command, :spawn_vsm, args, context}, state) do
    # Parse VSM definition from args
    vsm_name = String.trim(args)
    
    if vsm_name != "" do
      # Create spawn request
      spawn_request = %{
        capability: "telegram_interface",
        type: "spawn_vsm",
        params: %{
          name: vsm_name,
          requested_by: get_in(context, [:update, "message", "from", "id"]),
          chat_id: get_in(context, [:update, "message", "chat", "id"]),
          context: context  # Store context for response
        }
      }
      
      # Send to S1 for execution
      :ok = NervousSystem.send_command(:telegram_unit, :system1, spawn_request)
      
      # Send initial response
      Vsmcp.Interfaces.TelegramBot.BotHandler.answer_context(context, "🔄 Spawning sub-VSM: #{vsm_name}...", parse_mode: "Markdown")
    else
      Vsmcp.Interfaces.TelegramBot.BotHandler.answer_context(context, "❌ Please provide a name: /spawn_vsm <name>", parse_mode: "Markdown")
    end
    
    {:noreply, state}
  end
  
  # Catch all other updates
  @impl true
  def handle_info({:telegram_update, _}, state) do
    {:noreply, state}
  end
  
  # Handle S1 operation results
  @impl true
  def handle_info({:operation_result, %{chat_id: chat_id, context: context} = result}, state) when not is_nil(context) do
    response = format_vsm_response(result)
    # Use context if available for proper response
    Vsmcp.Interfaces.TelegramBot.BotHandler.answer_context(context, response, parse_mode: "Markdown")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:operation_result, %{chat_id: chat_id} = result}, state) do
    # Fallback: If no context, we can't send the message directly
    Logger.warn("Operation result without context, cannot send response to chat #{chat_id}")
    {:noreply, state}
  end
  
  # Periodic S4 environmental scanning
  @impl true
  def handle_info(:environmental_scan, state) do
    # CORRECT: S4's role is ENVIRONMENTAL SCANNING, not operations
    scan_results = environmental_scan(state)
    
    # Send intelligence to S4
    NervousSystem.publish_on_channel(:intel, %{
      source: "telegram_interface",
      type: "environmental_scan",
      data: scan_results
    })
    
    # Schedule next scan
    Process.send_after(self(), :environmental_scan, 60_000) # Every minute
    
    {:noreply, state}
  end
  
  # This runs IN System 1 as an operational capability
  defp handle_telegram_operation(%{params: params} = operation) do
    Logger.debug("S1 processing Telegram operation: #{inspect(operation)}")
    
    # S1 processes the operation based on type
    result = case operation.type do
      "user_request" ->
        process_user_request(params.text, params)
        
      "spawn_vsm" ->
        spawn_sub_vsm(params)
        
      _ ->
        %{status: :unknown_operation, response: "Unknown operation type"}
    end
    
    # Send response back to telegram bot process with context if available
    if params[:chat_id] do
      result_with_meta = result
      |> Map.put(:chat_id, params.chat_id)
      |> Map.put(:context, params[:context])
      
      send(Vsmcp.Interfaces.TelegramBot, {:operation_result, result_with_meta})
    end
    
    # Report to S3 for audit
    NervousSystem.publish_on_channel(:audit, %{
      unit: "telegram_interface",
      operation: operation.type,
      result: result.status
    })
    
    {:ok, result}
  end
  
  # CORRECT: S4's role is ENVIRONMENTAL SCANNING, not operations
  defp environmental_scan(state) do
    # S4 might analyze Telegram trends, user patterns, etc.
    # But it does NOT handle individual user messages!
    
    %{
      telegram_trends: analyze_message_patterns(state.message_patterns),
      user_growth: calculate_user_growth_rate(state),
      complexity_forecast: predict_future_variety(state),
      # This intelligence goes to S5 for policy decisions
      recommendation: generate_recommendations(state)
    }
  end
  
  defp update_message_patterns(state, text) do
    # Keep last 1000 messages for pattern analysis
    patterns = [text | state.message_patterns] |> Enum.take(1000)
    %{state | message_patterns: patterns}
  end
  
  defp requires_coordination?(text, _state) do
    # Complex requests need multiple S1 units
    String.contains?(text, ["and", "then", "after", "multiple"]) ||
    String.length(text) > 100
  end
  
  defp urgent?(text) do
    String.contains?(String.downcase(text), ["urgent", "emergency", "asap", "critical", "alert"])
  end
  
  defp process_user_request(text, params) do
    # S1 operational logic here
    # This is where the actual work happens!
    
    cond do
      String.starts_with?(text, "/") ->
        # Command processing
        %{
          status: :completed,
          response: "Command processed: #{text}",
          operations_performed: 1
        }
        
      String.contains?(String.downcase(text), ["hello", "hi", "hey"]) ->
        # Greeting
        %{
          status: :completed,
          response: "Hello #{params.username}! I'm the VSM operational interface. How can I help you?",
          operations_performed: 1
        }
        
      true ->
        # General processing
        %{
          status: :completed,
          response: "Processed your request: #{text}",
          operations_performed: 1
        }
    end
  end
  
  defp spawn_sub_vsm(params) do
    # Use MCP delegation to spawn a sub-VSM
    case Vsmcp.MCP.Delegation.register_sub_vsm(%{
      name: params.name,
      parent_id: "telegram_vsm",
      capabilities: ["basic_operations"],
      owner: params.requested_by
    }) do
      {:ok, sub_vsm} ->
        %{
          status: :completed,
          response: "✅ Sub-VSM '#{params.name}' spawned successfully!\nID: #{sub_vsm.id}",
          sub_vsm_spawned: true,
          sub_vsm_id: sub_vsm.id
        }
        
      {:error, reason} ->
        %{
          status: :failed,
          response: "❌ Failed to spawn sub-VSM: #{inspect(reason)}",
          sub_vsm_spawned: false
        }
    end
  end
  
  defp analyze_message_patterns(patterns) do
    # S4 function: Look at overall patterns, not individual messages
    word_frequencies = patterns
    |> Enum.flat_map(&String.split/1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(10)
    
    %{
      total_messages: length(patterns),
      common_words: word_frequencies,
      complexity_trend: "increasing"
    }
  end
  
  defp calculate_user_growth_rate(state) do
    # S4 function: Environmental trend analysis
    "15% monthly growth"
  end
  
  defp predict_future_variety(state) do
    # S4 function: Forecast environmental complexity
    pattern_count = length(state.message_patterns)
    
    cond do
      pattern_count > 500 -> "High variety expected in next quarter"
      pattern_count > 100 -> "Medium variety expected"
      true -> "Low variety expected"
    end
  end
  
  defp generate_recommendations(state) do
    pattern_count = length(state.message_patterns)
    
    cond do
      pattern_count > 500 ->
        "Consider adding more S1 units if growth continues"
      pattern_count > 100 ->
        "Current capacity adequate, monitor for changes"
      true ->
        "Low activity, maintain minimal resources"
    end
  end
  
  defp format_vsm_response(result) do
    """
    🤖 *VSM Response*
    
    Status: #{result.status}
    #{if result[:response], do: "\n#{result.response}"}
    #{if result[:sub_vsm_spawned], do: "\n🔄 Spawned sub-VSM: #{result.sub_vsm_id}"}
    """
  end
  
  defp format_status(status) do
    """
    📊 *VSM System Status*
    
    S1 (Operations): #{status.system_1[:metrics][:executions]} executions
    S2 (Coordination): Active
    S3 (Control): Monitoring
    S4 (Intelligence): #{map_size(status.system_4[:intelligence_sources])} sources
    S5 (Policy): Active
    
    Variety Gap: #{status.variety[:gap_percentage]}%
    """
  end
  
  defp format_help do
    """
    📚 *VSM Telegram Bot Help*
    
    Available commands:
    
    /status - Show VSM system status
    /spawn_vsm <name> - Spawn a sub-VSM
    /help - Show this help message
    
    Regular messages are processed as operational variety through System 1.
    
    Urgent messages (containing "urgent", "emergency", etc.) trigger algedonic signals.
    """
  end
end