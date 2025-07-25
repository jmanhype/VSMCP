defmodule Vsmcp.Interfaces.TelegramBot.BotHandler do
  @moduledoc """
  Telegram Bot Handler module following enterprise patterns.
  
  This module acts as a bridge between ExGram API and the internal TelegramBot GenServer,
  providing error handling, circuit breaker pattern, and structured logging.
  
  Key Functions:
  - `answer_context/3` - Send responses via ExGram with error handling
  - `bot/0` - Bot configuration for ExGram integration
  - Circuit breaker pattern for resilience
  - Structured logging for operations
  """
  
  require Logger
  use GenServer
  import ExGram.Dsl, only: [answer: 3]
  
  # Circuit breaker states
  @circuit_breaker_failure_threshold 5
  @circuit_breaker_recovery_timeout 30_000
  @circuit_breaker_half_open_max_calls 3
  
  defstruct [
    :circuit_state,
    :failure_count,
    :last_failure_time,
    :half_open_calls
  ]
  
  @doc """
  Bot configuration for ExGram integration.
  Returns configuration map with token and method.
  """
  def bot do
    token = get_bot_token()
    
    %{
      token: token,
      method: :polling,
      timeout: 30_000
    }
  end
  
  @doc """
  Start the BotHandler GenServer for circuit breaker state management.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Send a response to a Telegram chat using ExGram context.
  
  ## Parameters
  - `context` - ExGram context containing chat and message information
  - `text` - Message text to send
  - `opts` - Optional parameters (parse_mode, reply_markup, etc.)
  
  ## Examples
      iex> answer_context(context, "Hello!", parse_mode: "Markdown")
      :ok
      
      iex> answer_context(context, "*Bold text*", parse_mode: "Markdown")
      :ok
  """
  def answer_context(context, text, opts \\ []) do
    Logger.info("BotHandler.answer_context called", %{
      chat_id: get_chat_id(context),
      text_length: String.length(text),
      opts: opts
    })
    
    with :ok <- check_circuit_breaker(),
         :ok <- validate_inputs(context, text),
         :ok <- send_message_with_retry(context, text, opts) do
      record_success()
      :ok
    else
      {:error, :circuit_breaker_open} ->
        Logger.warning("Circuit breaker is open, rejecting request")
        {:error, :service_unavailable}
        
      {:error, reason} = error ->
        record_failure(reason)
        Logger.error("Failed to send Telegram message", %{
          error: reason,
          chat_id: get_chat_id(context),
          text_preview: if(is_binary(text), do: String.slice(text, 0, 100), else: inspect(text))
        })
        error
    end
  end
  
  @doc """
  Get bot information and status.
  """
  def bot_info do
    case get_bot_token() do
      nil ->
        {:error, :no_token_configured}
        
      token ->
        {:ok, %{
          token_configured: true,
          token_length: String.length(token),
          circuit_breaker_state: get_circuit_breaker_state()
        }}
    end
  end
  
  @doc """
  Reset circuit breaker to closed state.
  """
  def reset_circuit_breaker do
    GenServer.call(__MODULE__, :reset_circuit_breaker)
  end
  
  # GenServer Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("Starting Telegram BotHandler with circuit breaker")
    
    {:ok, %__MODULE__{
      circuit_state: :closed,
      failure_count: 0,
      last_failure_time: nil,
      half_open_calls: 0
    }}
  end
  
  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
  
  @impl true
  def handle_call(:reset_circuit_breaker, _from, state) do
    new_state = %{state | 
      circuit_state: :closed,
      failure_count: 0,
      last_failure_time: nil,
      half_open_calls: 0
    }
    
    Logger.info("Circuit breaker reset to closed state")
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call({:record_failure, reason}, _from, state) do
    new_failure_count = state.failure_count + 1
    now = System.monotonic_time(:millisecond)
    
    new_state = cond do
      new_failure_count >= @circuit_breaker_failure_threshold ->
        Logger.warning("Circuit breaker opened due to #{new_failure_count} failures", %{
          last_failure: reason
        })
        %{state | 
          circuit_state: :open,
          failure_count: new_failure_count,
          last_failure_time: now,
          half_open_calls: 0
        }
        
      true ->
        %{state | 
          failure_count: new_failure_count,
          last_failure_time: now
        }
    end
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:record_success, _from, state) do
    new_state = case state.circuit_state do
      :half_open ->
        Logger.info("Circuit breaker closed after successful call")
        %{state | 
          circuit_state: :closed,
          failure_count: 0,
          last_failure_time: nil,
          half_open_calls: 0
        }
        
      _ ->
        %{state | failure_count: max(0, state.failure_count - 1)}
    end
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:check_circuit_breaker, _from, state) do
    now = System.monotonic_time(:millisecond)
    
    result = case state.circuit_state do
      :closed ->
        {:reply, :ok, state}
        
      :open ->
        if now - state.last_failure_time > @circuit_breaker_recovery_timeout do
          Logger.info("Circuit breaker transitioning to half-open")
          new_state = %{state | circuit_state: :half_open, half_open_calls: 0}
          {:reply, :ok, new_state}
        else
          {:reply, {:error, :circuit_breaker_open}, state}
        end
        
      :half_open ->
        if state.half_open_calls < @circuit_breaker_half_open_max_calls do
          new_state = %{state | half_open_calls: state.half_open_calls + 1}
          {:reply, :ok, new_state}
        else
          {:reply, {:error, :circuit_breaker_open}, state}
        end
    end
    
    result
  end
  
  # Private Functions
  
  defp get_bot_token do
    # Try multiple configuration sources
    token = Application.get_env(:vsmcp, :telegram_bot_token) ||
            Application.get_env(:ex_gram, :token) ||
            get_env_token()
    
    # Return nil if token is empty string or false
    case token do
      "" -> nil
      false -> nil
      nil -> nil
      t when is_binary(t) -> t
      _ -> nil
    end
  end
  
  defp get_env_token do
    case System.get_env("TELEGRAM_BOT_TOKEN") do
      nil -> nil
      "" -> nil
      token -> token
    end
  end
  
  defp validate_inputs(context, text) do
    cond do
      is_nil(context) ->
        {:error, :invalid_context}
        
      is_nil(text) or text == "" ->
        {:error, :empty_message}
        
      String.length(text) > 4096 ->
        {:error, :message_too_long}
        
      is_nil(get_chat_id(context)) ->
        {:error, :no_chat_id}
        
      true ->
        :ok
    end
  end
  
  defp get_chat_id(context) do
    try do
      context.update.message.chat.id
    rescue
      _ ->
        try do
          context.update.callback_query.message.chat.id
        rescue
          _ -> nil
        end
    end
  end
  
  defp send_message_with_retry(context, text, opts, retries \\ 3) do
    try do
      # Use ExGram's DSL answer function - it returns the context
      # ExGram handles the actual API call internally
      _updated_context = answer(context, text, opts)
      :ok
    rescue
      error in [ExGram.Error] ->
        case error.code do
          429 ->
            # Rate limit - exponential backoff
            if retries > 0 do
              retry_after = extract_retry_after(error) || 1000
              Logger.warning("Rate limited, retrying after #{retry_after}ms")
              Process.sleep(retry_after)
              send_message_with_retry(context, text, opts, retries - 1)
            else
              {:error, :rate_limit_exceeded}
            end
            
          _ ->
            Logger.error("Telegram API error", %{code: error.code, message: error.message})
            {:error, {:api_error, error.code, error.message}}
        end
        
      exception ->
        Logger.error("Exception in send_message", %{
          exception: inspect(exception),
          stacktrace: Process.info(self(), :current_stacktrace)
        })
        {:error, {:exception, exception}}
    end
  end
  
  defp extract_retry_after(%ExGram.Error{} = error) do
    # Try to extract retry_after from error metadata
    case error.metadata do
      %{"retry_after" => retry_after} when is_integer(retry_after) ->
        retry_after * 1000  # Convert to milliseconds
      _ ->
        nil
    end
  end
  
  defp check_circuit_breaker do
    case Process.whereis(__MODULE__) do
      nil ->
        # Circuit breaker not running, allow the call
        :ok
        
      pid ->
        GenServer.call(pid, :check_circuit_breaker)
    end
  end
  
  defp record_failure(reason) do
    case Process.whereis(__MODULE__) do
      nil ->
        :ok
        
      pid ->
        GenServer.call(pid, {:record_failure, reason})
    end
  end
  
  defp record_success do
    case Process.whereis(__MODULE__) do
      nil ->
        :ok
        
      pid ->
        GenServer.call(pid, :record_success)
    end
  end
  
  defp get_circuit_breaker_state do
    case Process.whereis(__MODULE__) do
      nil ->
        :not_running
        
      pid ->
        try do
          state = GenServer.call(pid, :get_state)
          state.circuit_state
        catch
          :exit, _ -> :unknown
        end
    end
  end
end