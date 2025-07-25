#!/usr/bin/env elixir

# Comprehensive Telegram integration test

Mix.install([
  {:ex_gram, "~> 0.52"},
  {:tesla, "~> 1.4"},
  {:hackney, "~> 1.18"},
  {:jason, "~> 1.4"}
])

defmodule IntegrationTest do
  @bot_token "7747520054:AAFNts5iJn8mYZezAG9uQF2_slvuztEScZI"
  @chat_id 643905554
  
  def run_all_tests do
    IO.puts("\n🔍 COMPREHENSIVE TELEGRAM INTEGRATION TEST\n")
    
    # Test 1: Bot connectivity
    IO.puts("1️⃣ Testing Bot Connectivity...")
    test_bot_connectivity()
    
    # Test 2: Polling mechanism
    IO.puts("\n2️⃣ Testing Polling Mechanism...")
    test_polling_mechanism()
    
    # Test 3: Message sending
    IO.puts("\n3️⃣ Testing Message Sending...")
    test_message_sending()
    
    # Test 4: Command handling
    IO.puts("\n4️⃣ Testing Command Handling...")
    test_command_handling()
    
    # Test 5: Network configuration
    IO.puts("\n5️⃣ Testing Network Configuration...")
    test_network_configuration()
    
    IO.puts("\n✅ All tests completed!")
  end
  
  defp test_bot_connectivity do
    Application.put_env(:ex_gram, :token, @bot_token)
    
    case ExGram.get_me() do
      {:ok, bot} ->
        IO.puts("✅ Bot connected successfully!")
        IO.puts("   Bot name: #{bot.first_name}")
        IO.puts("   Username: @#{bot.username}")
        IO.puts("   Bot ID: #{bot.id}")
      {:error, error} ->
        IO.puts("❌ Bot connection failed: #{inspect(error)}")
    end
  end
  
  defp test_polling_mechanism do
    # Get current update offset
    case ExGram.get_updates() do
      {:ok, updates} ->
        IO.puts("✅ Polling works! Found #{length(updates)} pending updates")
        
        if length(updates) > 0 do
          latest_update_id = List.last(updates).update_id
          IO.puts("   Latest update ID: #{latest_update_id}")
          
          # Test acknowledged polling
          case ExGram.get_updates(offset: latest_update_id + 1) do
            {:ok, new_updates} ->
              IO.puts("✅ Offset polling works! #{length(new_updates)} new updates after offset")
            {:error, error} ->
              IO.puts("❌ Offset polling failed: #{inspect(error)}")
          end
        end
      {:error, error} ->
        IO.puts("❌ Polling failed: #{inspect(error)}")
    end
  end
  
  defp test_message_sending do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    test_message = "🧪 Integration test at #{timestamp}"
    
    case ExGram.send_message(@chat_id, test_message) do
      {:ok, message} ->
        IO.puts("✅ Message sent successfully!")
        IO.puts("   Message ID: #{message.message_id}")
        IO.puts("   Chat ID: #{message.chat.id}")
      {:error, error} ->
        IO.puts("❌ Message sending failed: #{inspect(error)}")
    end
  end
  
  defp test_command_handling do
    # Send test commands
    commands = [
      {"/status", "Testing /status command"},
      {"/help", "Testing /help command"},
      {"/spawn_vsm test_integration", "Testing /spawn_vsm command"}
    ]
    
    Enum.each(commands, fn {command, description} ->
      IO.puts("\n   Testing: #{command}")
      
      case ExGram.send_message(@chat_id, command) do
        {:ok, _} ->
          IO.puts("   ✅ #{description} - sent")
          Process.sleep(1000) # Give bot time to process
        {:error, error} ->
          IO.puts("   ❌ #{description} - failed: #{inspect(error)}")
      end
    end)
  end
  
  defp test_network_configuration do
    IO.puts("   Checking Telegram API connectivity...")
    
    # Test direct HTTPS connection
    case :hackney.request(:get, "https://api.telegram.org/bot#{@bot_token}/getMe", [], "", []) do
      {:ok, 200, _headers, _ref} ->
        IO.puts("   ✅ HTTPS connection to Telegram API successful")
      {:ok, status, _headers, _ref} ->
        IO.puts("   ⚠️  Telegram API returned status: #{status}")
      {:error, reason} ->
        IO.puts("   ❌ Network error: #{inspect(reason)}")
    end
    
    # Check webhook status
    case ExGram.get_webhook_info() do
      {:ok, webhook_info} ->
        if webhook_info.url == "" do
          IO.puts("   ✅ Webhook not set (using polling mode)")
        else
          IO.puts("   ⚠️  Webhook is set to: #{webhook_info.url}")
          IO.puts("      This may interfere with polling!")
        end
      {:error, error} ->
        IO.puts("   ❌ Failed to get webhook info: #{inspect(error)}")
    end
  end
end

# Run the tests
IntegrationTest.run_all_tests()