#!/usr/bin/env elixir

# Test different ways to start ExGram bot

test_token = "7747520054:AAFNts5iJn8mYZezAG9uQF2_slvuztEScZI"

IO.puts("Testing ExGram startup methods...\n")

# Set configuration
Application.put_env(:ex_gram, :token, test_token)

# Method 1: Direct start
IO.puts("Method 1: Direct module start")
try do
  result = Vsmcp.Interfaces.TelegramBotSimple.start_link(
    token: test_token,
    method: :polling
  )
  IO.puts("Result: #{inspect(result)}")
rescue
  e -> 
    IO.puts("Error: #{inspect(e)}")
    IO.puts("Message: #{Exception.message(e)}")
end

IO.puts("\nMethod 2: Using Supervisor child spec format")
try do
  # Start a test supervisor
  children = [
    {Vsmcp.Interfaces.TelegramBotSimple, 
      token: test_token,
      method: :polling
    }
  ]
  
  result = Supervisor.start_link(children, strategy: :one_for_one, name: TestSupervisor)
  IO.puts("Supervisor result: #{inspect(result)}")
  
  if elem(result, 0) == :ok do
    Process.sleep(1000)
    children = Supervisor.which_children(TestSupervisor)
    IO.puts("Children: #{inspect(children)}")
  end
rescue
  e -> 
    IO.puts("Error: #{inspect(e)}")
    IO.puts("Message: #{Exception.message(e)}")
end

IO.puts("\nMethod 3: Check ExGram.Bot __using__ macro")
# The ExGram.Bot macro should define child_spec automatically
IO.puts("TelegramBotSimple exports child_spec/1: #{function_exported?(Vsmcp.Interfaces.TelegramBotSimple, :child_spec, 1)}")

if function_exported?(Vsmcp.Interfaces.TelegramBotSimple, :child_spec, 1) do
  spec = Vsmcp.Interfaces.TelegramBotSimple.child_spec(token: test_token, method: :polling)
  IO.puts("Child spec: #{inspect(spec)}")
end