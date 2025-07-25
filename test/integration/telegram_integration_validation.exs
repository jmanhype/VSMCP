defmodule Vsmcp.Integration.TelegramIntegrationValidation do
  @moduledoc """
  Integration validation test focusing on the 4 critical answer_context calls
  and basic functionality without complex test scenarios.
  """
  use ExUnit.Case, async: false
  
  alias Vsmcp.Interfaces.TelegramBot.BotHandler
  
  import Mock
  
  setup_all do
    # Ensure BotHandler is started
    case GenServer.whereis(BotHandler) do
      nil -> {:ok, _} = BotHandler.start_link([])
      _ -> :ok
    end
    
    :ok
  end
  
  setup do
    # Reset circuit breaker for clean state
    BotHandler.reset_circuit_breaker()
    :ok
  end

  describe "Core Integration Validation" do
    test "BotHandler.answer_context/3 function exists and is callable" do
      assert function_exported?(BotHandler, :answer_context, 3)
      assert function_exported?(BotHandler, :bot, 0)
      assert function_exported?(BotHandler, :bot_info, 0)
    end
    
    test "all 4 existing answer_context calls work correctly" do
      mock_context = create_mock_context("123", "TestUser")
      
      with_mock ExGram.Dsl, [answer: fn(ctx, _text, _opts) -> ctx end] do
        # Test Call #1: Status response (telegram_bot.ex:94)
        result1 = BotHandler.answer_context(mock_context, "📊 *VSM System Status*", parse_mode: "Markdown")
        assert result1 == :ok
        
        # Test Call #2: Spawn VSM progress (telegram_bot.ex:121)
        result2 = BotHandler.answer_context(mock_context, "🔄 Spawning sub-VSM: test...", parse_mode: "Markdown")
        assert result2 == :ok
        
        # Test Call #3: Spawn VSM error (telegram_bot.ex:123)
        result3 = BotHandler.answer_context(mock_context, "❌ Please provide a name: /spawn_vsm <name>", parse_mode: "Markdown")
        assert result3 == :ok
        
        # Test Call #4: Operation result (telegram_bot.ex:140)
        result4 = BotHandler.answer_context(mock_context, "🤖 *VSM Response*\n\nStatus: completed", parse_mode: "Markdown")
        assert result4 == :ok
        
        # Verify all calls were made to ExGram
        assert_called ExGram.Dsl.answer(mock_context, "📊 *VSM System Status*", [parse_mode: "Markdown"])
        assert_called ExGram.Dsl.answer(mock_context, "🔄 Spawning sub-VSM: test...", [parse_mode: "Markdown"])
        assert_called ExGram.Dsl.answer(mock_context, "❌ Please provide a name: /spawn_vsm <name>", [parse_mode: "Markdown"])
        assert_called ExGram.Dsl.answer(mock_context, "🤖 *VSM Response*\n\nStatus: completed", [parse_mode: "Markdown"])
      end
    end
    
    test "bot configuration works correctly" do
      # Set test token
      Application.put_env(:vsmcp, :telegram_bot_token, "test_token_123")
      
      config = BotHandler.bot()
      
      assert is_map(config)
      assert config.token == "test_token_123"
      assert config.method == :polling
      assert config.timeout == 30_000
    end
    
    test "input validation works correctly" do
      mock_context = create_mock_context("123", "TestUser")
      
      # Test valid input
      with_mock ExGram.Dsl, [answer: fn(ctx, _, _) -> ctx end] do
        assert :ok = BotHandler.answer_context(mock_context, "Valid message")
      end
      
      # Test invalid inputs
      assert {:error, :invalid_context} = BotHandler.answer_context(nil, "message")
      assert {:error, :empty_message} = BotHandler.answer_context(mock_context, "")
      assert {:error, :empty_message} = BotHandler.answer_context(mock_context, nil)
      
      # Test message too long
      long_message = String.duplicate("x", 4097)
      assert {:error, :message_too_long} = BotHandler.answer_context(mock_context, long_message)
    end
    
    test "error handling works correctly" do
      mock_context = create_mock_context("123", "TestUser")
      
      # Test API error handling
      api_error = %ExGram.Error{code: 400, message: "Bad Request"}
      
      with_mock ExGram.Dsl, [answer: fn(_, _, _) -> raise api_error end] do
        result = BotHandler.answer_context(mock_context, "Test message")
        assert {:error, {:api_error, 400, "Bad Request"}} = result
      end
    end
    
    test "circuit breaker basic functionality" do
      mock_context = create_mock_context("123", "TestUser")
      
      # Test normal operation
      with_mock ExGram.Dsl, [answer: fn(ctx, _, _) -> ctx end] do
        assert :ok = BotHandler.answer_context(mock_context, "Normal message")
      end
      
      # Test that circuit breaker can be reset
      assert :ok = BotHandler.reset_circuit_breaker()
    end
  end
  
  describe "ExGram Integration" do
    test "bot_info returns meaningful data" do
      Application.put_env(:vsmcp, :telegram_bot_token, "test_token")
      
      {:ok, info} = BotHandler.bot_info()
      
      assert is_map(info)
      assert info.token_configured == true
      assert is_integer(info.token_length)
      assert info.circuit_breaker_state in [:closed, :open, :half_open, :not_running]
    end
    
    test "bot_info handles missing token" do
      Application.delete_env(:vsmcp, :telegram_bot_token)
      System.delete_env("TELEGRAM_BOT_TOKEN")
      
      assert {:error, :no_token_configured} = BotHandler.bot_info()
    end
  end
  
  # Helper function to create mock ExGram context
  defp create_mock_context(chat_id, username) do
    %{
      update: %{
        message: %{
          chat: %{id: chat_id},
          from: %{id: chat_id, username: username},
          text: "test message"
        }
      }
    }
  end
end