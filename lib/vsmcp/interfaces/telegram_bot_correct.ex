# Path: lib/vsmcp/interfaces/telegram_bot_correct.ex
defmodule Vsmcp.Interfaces.TelegramBotCorrect do
  @moduledoc """
  Telegram Bot interface following Stafford Beer's VSM principles.
  External variety (user messages) enters through System 1 (Operations).
  System 4 scans the environment but doesn't handle operations.
  """
  use GenServer
  require Logger
  
  alias Vsmcp.AMQP.NervousSystem
  alias Vsmcp.Systems.System1
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    # Register as S1 operational capability
    :ok = System1.register_capability("telegram_interface", &handle_telegram_operation/1)
    
    {:ok, %{
      token: opts[:token] || System.get_env("TELEGRAM_BOT_TOKEN"),
      # Each chat is an operational unit in S1
      operational_units: %{}
    }}
  end
  
  # CORRECT: Telegram messages are OPERATIONAL VARIETY entering S1
  def handle_info({:telegram_update, %{message: %{text: text, from: user}}}, state) do
    Logger.info("Operational variety from Telegram user #{user.id}: #{text}")
    
    # 1. This is OPERATIONAL VARIETY - goes to System 1!
    operation = %{
      capability: "telegram_interface",
      type: "user_request",
      params: %{
        text: text,
        user_id: user.id,
        chat_id: user.id
      }
    }
    
    # 2. Send to S1 as operational command (not to S4!)
    :ok = NervousSystem.send_command(:telegram_unit, :system1, operation)
    
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
    
    {:noreply, state}
  end
  
  # This runs IN System 1 as an operational capability
  defp handle_telegram_operation(%{params: params}) do
    # S1 processes the operation
    result = process_user_request(params.text)
    
    # Send response back to user
    send_telegram_response(params.chat_id, result)
    
    # Report to S3 for audit
    NervousSystem.publish_on_channel(:audit, %{
      unit: "telegram_interface",
      operation: "user_request",
      result: result.status
    })
    
    {:ok, result}
  end
  
  # CORRECT: S4's role is ENVIRONMENTAL SCANNING, not operations
  def environmental_scan do
    # S4 might analyze Telegram trends, user patterns, etc.
    # But it does NOT handle individual user messages!
    
    # This would run periodically in S4:
    %{
      telegram_trends: analyze_message_patterns(),
      user_growth: calculate_user_growth_rate(),
      complexity_forecast: predict_future_variety(),
      # This intelligence goes to S5 for policy decisions
      recommendation: "Consider adding more S1 units if growth continues"
    }
  end
  
  defp requires_coordination?(text, _state) do
    # Complex requests need multiple S1 units
    String.contains?(text, ["and", "then", "after", "multiple"]) ||
    String.length(text) > 100
  end
  
  defp urgent?(text) do
    String.contains?(String.downcase(text), ["urgent", "emergency", "asap", "critical"])
  end
  
  defp process_user_request(text) do
    # S1 operational logic here
    # This is where the actual work happens!
    %{
      status: :completed,
      response: "Processed: #{text}",
      operations_performed: 1
    }
  end
  
  defp send_telegram_response(chat_id, result) do
    # Direct operational response from S1
    ExGram.send_message(chat_id, result.response)
  end
  
  defp analyze_message_patterns do
    # S4 function: Look at overall patterns, not individual messages
    "increasing complexity in user requests"
  end
  
  defp calculate_user_growth_rate do
    # S4 function: Environmental trend analysis
    "15% monthly growth"
  end
  
  defp predict_future_variety do
    # S4 function: Forecast environmental complexity
    "High variety expected in next quarter"
  end
end