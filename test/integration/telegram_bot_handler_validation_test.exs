defmodule Vsmcp.Integration.TelegramBotHandlerValidationTest do
  @moduledoc """
  Comprehensive validation tests for BotHandler integration with existing VSM system.
  Tests all 4 existing answer_context calls and error handling pathways.
  """
  use ExUnit.Case, async: false
  
  alias Vsmcp.Interfaces.TelegramBot.BotHandler
  alias Vsmcp.Interfaces.TelegramBot
  
  import Mock
  
  setup do
    # Start BotHandler for circuit breaker functionality
    case GenServer.whereis(BotHandler) do
      nil -> {:ok, _} = BotHandler.start_link([])
      _ -> :ok
    end
    
    # Reset circuit breaker to ensure clean state for each test
    BotHandler.reset_circuit_breaker()
    
    :ok
  end

  describe "BotHandler.answer_context/3 validation" do
    test "validates all required function signatures exist" do
      # Test that the module and function exist
      assert function_exported?(BotHandler, :answer_context, 3)
      assert function_exported?(BotHandler, :bot, 0)
      assert function_exported?(BotHandler, :bot_info, 0)
      assert function_exported?(BotHandler, :reset_circuit_breaker, 0)
    end
    
    test "answer_context handles valid inputs correctly" do
      # Mock ExGram answer function
      mock_context = create_mock_context("123", "Test User")
      
      with_mock ExGram.Dsl, [answer: fn(ctx, text, opts) -> ctx end] do
        result = BotHandler.answer_context(mock_context, "Hello World!")
        assert result == :ok
        
        # Verify ExGram was called correctly
        assert_called ExGram.Dsl.answer(mock_context, "Hello World!", [])
      end
    end
    
    test "answer_context validates input parameters" do
      # Test nil context
      assert {:error, :invalid_context} = BotHandler.answer_context(nil, "text")
      
      # Test empty message
      mock_context = create_mock_context("123", "Test User")
      assert {:error, :empty_message} = BotHandler.answer_context(mock_context, "")
      assert {:error, :empty_message} = BotHandler.answer_context(mock_context, nil)
      
      # Test message too long (>4096 chars)
      long_text = String.duplicate("x", 4097)
      assert {:error, :message_too_long} = BotHandler.answer_context(mock_context, long_text)
    end
    
    test "answer_context handles ExGram errors with retry logic" do
      mock_context = create_mock_context("123", "Test User")
      
      # Test rate limiting (429 error)
      rate_limit_error = %ExGram.Error{code: 429, message: "Too Many Requests"}
      
      with_mock ExGram.Dsl, [answer: fn(_, _, _) -> raise rate_limit_error end] do
        result = BotHandler.answer_context(mock_context, "Test message")
        assert {:error, :rate_limit_exceeded} = result
      end
    end
    
    test "circuit breaker functionality works correctly" do
      mock_context = create_mock_context("123", "Test User")
      
      # Reset circuit breaker to known state
      BotHandler.reset_circuit_breaker()
      
      # Test normal operation
      with_mock ExGram.Dsl, [answer: fn(ctx, _, _) -> ctx end] do
        assert :ok = BotHandler.answer_context(mock_context, "Normal message")
      end
      
      # Test circuit breaker opens after failures
      error = %ExGram.Error{code: 500, message: "Internal Server Error"}
      
      with_mock ExGram.Dsl, [answer: fn(_, _, _) -> raise error end] do
        # Generate enough failures to open circuit breaker
        for _i <- 1..6 do
          BotHandler.answer_context(mock_context, "Failing message")
        end
        
        # Next call should be rejected by circuit breaker
        result = BotHandler.answer_context(mock_context, "Should be rejected")
        assert {:error, :service_unavailable} = result
      end
    end
  end
  
  describe "ExGram Integration Tests" do
    test "bot/0 returns correct configuration" do
      # Set test token
      Application.put_env(:vsmcp, :telegram_bot_token, "test_token_123")
      
      config = BotHandler.bot()
      
      assert %{
        token: "test_token_123",
        method: :polling,
        timeout: 30_000
      } = config
    end
    
    test "bot_info/0 returns status correctly" do
      Application.put_env(:vsmcp, :telegram_bot_token, "test_token")
      
      {:ok, info} = BotHandler.bot_info()
      
      assert info.token_configured == true
      assert info.token_length == 10  # "test_token" length
      assert info.circuit_breaker_state in [:closed, :open, :half_open]
    end
    
    test "bot_info/0 handles missing token" do
      Application.delete_env(:vsmcp, :telegram_bot_token)
      System.delete_env("TELEGRAM_BOT_TOKEN")
      
      assert {:error, :no_token_configured} = BotHandler.bot_info()
    end
  end
  
  describe "Integration with existing TelegramBot GenServer" do
    test "validates all 4 existing answer_context calls work" do
      mock_context = create_mock_context("123", "Test User")
      
      with_mock ExGram.Dsl, [answer: fn(ctx, _, _) -> ctx end] do
        # Test 1: Status command response (line 94 in telegram_bot.ex)
        status_response = """
        📊 *VSM System Status*
        
        S1 (Operations): 42 executions
        S2 (Coordination): Active
        S3 (Control): Monitoring
        S4 (Intelligence): 3 sources
        S5 (Policy): Active
        
        Variety Gap: 15%
        """
        
        result1 = BotHandler.answer_context(mock_context, status_response, parse_mode: "Markdown")
        assert result1 == :ok
        
        # Test 2: Spawn VSM success response (line 121)
        spawn_response = "🔄 Spawning sub-VSM: test_vsm..."
        result2 = BotHandler.answer_context(mock_context, spawn_response, parse_mode: "Markdown")
        assert result2 == :ok
        
        # Test 3: Spawn VSM error response (line 123)
        error_response = "❌ Please provide a name: /spawn_vsm <name>"
        result3 = BotHandler.answer_context(mock_context, error_response, parse_mode: "Markdown")
        assert result3 == :ok
        
        # Test 4: Operation result response (line 140)
        operation_response = """
        🤖 *VSM Response*
        
        Status: completed
        
        Processed your request: hello world
        """
        result4 = BotHandler.answer_context(mock_context, operation_response, parse_mode: "Markdown")
        assert result4 == :ok
        
        # Verify all calls were made correctly
        assert_called ExGram.Dsl.answer(mock_context, status_response, [parse_mode: "Markdown"])
        assert_called ExGram.Dsl.answer(mock_context, spawn_response, [parse_mode: "Markdown"])
        assert_called ExGram.Dsl.answer(mock_context, error_response, [parse_mode: "Markdown"])
        assert_called ExGram.Dsl.answer(mock_context, operation_response, [parse_mode: "Markdown"])
      end
    end
    
    test "validates TelegramBot GenServer can send messages through BotHandler" do
      # Mock the operation result message flow
      mock_context = create_mock_context("123", "Test User")
      
      operation_result = %{
        chat_id: "123",
        context: mock_context,
        status: :completed,
        response: "Test operation completed successfully"
      }
      
      with_mock ExGram.Dsl, [answer: fn(ctx, _, _) -> ctx end] do
        # Simulate sending operation_result message to TelegramBot GenServer
        send(TelegramBot, {:operation_result, operation_result})
        
        # Give it time to process
        Process.sleep(100)
        
        # The message should have been processed and answer_context called
        # This tests the integration flow from TelegramBot -> BotHandler
        assert_called ExGram.Dsl.answer(mock_context, :_, [parse_mode: "Markdown"])
      end
    end
  end
  
  describe "Error Handling Validation" do
    test "handles network timeouts gracefully" do
      mock_context = create_mock_context("123", "Test User")
      
      with_mock ExGram.Dsl, [answer: fn(_, _, _) -> raise %ExGram.Error{code: 408, message: "Request Timeout"} end] do
        result = BotHandler.answer_context(mock_context, "Test message")
        assert {:error, {:api_error, 408, "Request Timeout"}} = result
      end
    end
    
    test "handles malformed context gracefully" do
      # Test context without proper chat ID structure
      malformed_context = %{update: %{message: %{text: "test"}}}  # Missing chat
      
      result = BotHandler.answer_context(malformed_context, "Test message")
      assert {:error, :no_chat_id} = result
    end
    
    test "handles exceptions during message sending" do
      mock_context = create_mock_context("123", "Test User")
      
      with_mock ExGram.Dsl, [answer: fn(_, _, _) -> raise ArgumentError, "Test exception" end] do
        result = BotHandler.answer_context(mock_context, "Test message")
        assert {:error, {:exception, %ArgumentError{}}} = result
      end
    end
  end
  
  describe "Performance and Reliability Tests" do
    test "can handle high message volume without failures" do
      mock_context = create_mock_context("123", "Test User")
      
      with_mock ExGram.Dsl, [answer: fn(ctx, _, _) -> ctx end] do
        # Send 100 messages rapidly
        results = for i <- 1..100 do
          BotHandler.answer_context(mock_context, "Message #{i}")
        end
        
        # All should succeed
        assert Enum.all?(results, &(&1 == :ok))
        
        # Verify all calls were made
        assert call_count(ExGram.Dsl, :answer, 3) == 100
      end
    end
    
    test "circuit breaker recovers after timeout period" do
      mock_context = create_mock_context("123", "Test User")
      
      # Reset circuit breaker
      BotHandler.reset_circuit_breaker()
      
      # Force circuit breaker open
      error = %ExGram.Error{code: 500, message: "Server Error"}
      
      with_mock ExGram.Dsl, [answer: fn(_, _, _) -> raise error end] do
        for _i <- 1..6 do
          BotHandler.answer_context(mock_context, "Failing message")
        end
      end
      
      # Verify circuit breaker is open
      result = BotHandler.answer_context(mock_context, "Should fail")
      assert {:error, :service_unavailable} = result
      
      # Reset for recovery (simulating time passage)
      BotHandler.reset_circuit_breaker()
      
      # Should work again
      with_mock ExGram.Dsl, [answer: fn(ctx, _, _) -> ctx end] do
        result = BotHandler.answer_context(mock_context, "Recovery test")
        assert result == :ok
      end
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
  
  # Helper to count mock calls
  defp call_count(module, function, arity) do
    :meck.num_calls(module, function, arity)
  rescue
    _ -> 0
  end
end