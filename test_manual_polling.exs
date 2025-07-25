#!/usr/bin/env elixir

# Test manual polling with ExGram API

# Add the project dependencies
Mix.install([
  {:ex_gram, "~> 0.52"},
  {:tesla, "~> 1.4"},
  {:hackney, "~> 1.18"},
  {:jason, "~> 1.4"}
])

defmodule ManualPollingTest do
  @bot_token "7747520054:AAFNts5iJn8mYZezAG9uQF2_slvuztEScZI"
  
  def test_polling do
    IO.puts("\n🔍 Testing Manual Polling with ExGram...")
    
    # Configure ExGram
    Application.put_env(:ex_gram, :token, @bot_token)
    
    # Test 1: Get bot info
    IO.puts("\n1️⃣ Testing getMe...")
    case ExGram.get_me() do
      {:ok, bot} ->
        IO.puts("✅ Bot info retrieved successfully:")
        IO.inspect(bot, pretty: true)
      {:error, error} ->
        IO.puts("❌ Failed to get bot info: #{inspect(error)}")
    end
    
    # Test 2: Get updates manually
    IO.puts("\n2️⃣ Testing getUpdates...")
    case ExGram.get_updates() do
      {:ok, updates} ->
        IO.puts("✅ Updates retrieved successfully:")
        IO.puts("📊 Found #{length(updates)} pending updates")
        
        Enum.each(updates, fn update ->
          if update.message do
            IO.puts("\n  📨 Message from: @#{update.message.from.username || "unknown"}")
            IO.puts("  📝 Text: #{update.message.text}")
            IO.puts("  🆔 Update ID: #{update.update_id}")
          end
        end)
        
      {:error, error} ->
        IO.puts("❌ Failed to get updates: #{inspect(error)}")
    end
    
    # Test 3: Test with offset to acknowledge updates
    IO.puts("\n3️⃣ Testing getUpdates with offset...")
    case ExGram.get_updates(offset: 379100138) do
      {:ok, updates} ->
        IO.puts("✅ Updates with offset retrieved successfully:")
        IO.puts("📊 Found #{length(updates)} new updates after offset")
      {:error, error} ->
        IO.puts("❌ Failed to get updates with offset: #{inspect(error)}")
    end
    
    # Test 4: Send a test message back
    IO.puts("\n4️⃣ Testing sendMessage...")
    chat_id = 643905554  # From the pending updates
    test_message = "🤖 Integration test successful! Bot is receiving updates correctly."
    
    case ExGram.send_message(chat_id, test_message) do
      {:ok, message} ->
        IO.puts("✅ Test message sent successfully!")
        IO.puts("📤 Message ID: #{message.message_id}")
      {:error, error} ->
        IO.puts("❌ Failed to send message: #{inspect(error)}")
    end
    
    IO.puts("\n✅ Manual polling test completed!")
  end
end

# Run the test
ManualPollingTest.test_polling()