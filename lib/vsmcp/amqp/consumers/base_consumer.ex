defmodule Vsmcp.AMQP.Consumers.BaseConsumer do
  @moduledoc """
  Base consumer behaviour for VSM nervous system message consumption.
  
  Provides common functionality and callbacks for system-specific consumers.
  """
  
  @callback handle_command(command :: map(), metadata :: map()) :: :ok | {:error, term()}
  @callback handle_audit(audit :: map(), metadata :: map()) :: :ok | {:error, term()}
  @callback handle_algedonic(signal :: map(), metadata :: map()) :: :ok | {:error, term()}
  @callback handle_horizontal(message :: map(), metadata :: map()) :: :ok | {:error, term()}
  @callback handle_intel(intel :: map(), metadata :: map()) :: :ok | {:error, term()}
  
  defmacro __using__(opts) do
    quote do
      use GenServer
      require Logger
      
      alias Vsmcp.AMQP.{ConnectionPool, ChannelManager}
      
      @behaviour Vsmcp.AMQP.Consumers.BaseConsumer
      @system unquote(opts[:system]) || raise "System must be specified"
      
      defstruct [
        :channel,
        :system,
        :subscriptions,
        :consumer_tags,
        :message_handler
      ]
      
      def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end
      
      @impl true
      def init(opts) do
        Process.flag(:trap_exit, true)
        state = %__MODULE__{
          system: @system,
          subscriptions: opts[:subscriptions] || default_subscriptions(),
          consumer_tags: %{},
          message_handler: opts[:message_handler] || self()
        }
        
        send(self(), :setup_consumers)
        {:ok, state}
      end
      
      @impl true
      def handle_info(:setup_consumers, state) do
        case setup_consumers(state) do
          {:ok, new_state} ->
            Logger.info("#{@system} consumer setup complete")
            {:noreply, new_state}
          
          {:error, reason} ->
            Logger.error("Failed to setup consumers for #{@system}: #{inspect(reason)}")
            Process.send_after(self(), :setup_consumers, 5_000)
            {:noreply, state}
        end
      end
      
      @impl true
      def handle_info({:basic_deliver, payload, metadata}, state) do
        with {:ok, message} <- Jason.decode(payload),
             :ok <- route_message(message, metadata, state) do
          acknowledge_message(metadata, state)
        else
          error ->
            Logger.error("Failed to process message: #{inspect(error)}")
            reject_message(metadata, state, requeue: false)
        end
        
        {:noreply, state}
      end
      
      @impl true
      def handle_info({:basic_consume_ok, %{consumer_tag: tag}}, state) do
        Logger.debug("Consumer registered with tag: #{tag}")
        {:noreply, state}
      end
      
      @impl true
      def handle_info({:basic_cancel, %{consumer_tag: tag}}, state) do
        Logger.warn("Consumer cancelled with tag: #{tag}")
        {:noreply, state}
      end
      
      @impl true
      def handle_info({:basic_cancel_ok, %{consumer_tag: tag}}, state) do
        Logger.debug("Consumer cancel confirmed for tag: #{tag}")
        new_tags = Map.delete(state.consumer_tags, tag)
        {:noreply, %{state | consumer_tags: new_tags}}
      end
      
      @impl true
      def terminate(_reason, state) do
        # Cancel all consumers
        Enum.each(state.consumer_tags, fn {_queue, tag} ->
          try do
            AMQP.Basic.cancel(state.channel, tag)
          catch
            _, _ -> :ok
          end
        end)
        
        # Close channel
        if state.channel do
          try do
            AMQP.Channel.close(state.channel)
          catch
            _, _ -> :ok
          end
        end
        
        :ok
      end
      
      # Default implementations (can be overridden)
      
      @impl true
      def handle_command(command, metadata) do
        Logger.info("#{@system} received command: #{inspect(command)}")
        :ok
      end
      
      @impl true
      def handle_audit(audit, metadata) do
        Logger.info("#{@system} received audit: #{inspect(audit)}")
        :ok
      end
      
      @impl true
      def handle_algedonic(signal, metadata) do
        Logger.warn("#{@system} received algedonic signal: #{inspect(signal)}")
        :ok
      end
      
      @impl true
      def handle_horizontal(message, metadata) do
        Logger.info("#{@system} received horizontal message: #{inspect(message)}")
        :ok
      end
      
      @impl true
      def handle_intel(intel, metadata) do
        Logger.info("#{@system} received intel: #{inspect(intel)}")
        :ok
      end
      
      # Private functions
      
      defp default_subscriptions do
        # Override in specific consumers
        []
      end
      
      defp setup_consumers(state) do
        ConnectionPool.with_connection(fn conn ->
          with {:ok, channel} <- AMQP.Channel.open(conn),
               :ok <- setup_channel_qos(channel),
               {:ok, consumer_tags} <- subscribe_to_queues(channel, state.subscriptions) do
            {:ok, %{state | channel: channel, consumer_tags: consumer_tags}}
          end
        end)
      end
      
      defp setup_channel_qos(channel) do
        # Set prefetch to 10 messages
        AMQP.Basic.qos(channel, prefetch_count: 10)
      end
      
      defp subscribe_to_queues(channel, subscriptions) do
        tags = 
          Enum.reduce_while(subscriptions, %{}, fn queue, acc ->
            case AMQP.Basic.consume(channel, queue) do
              {:ok, tag} ->
                Logger.debug("Subscribed to #{queue} with tag #{tag}")
                {:cont, Map.put(acc, queue, tag)}
              
              error ->
                Logger.error("Failed to subscribe to #{queue}: #{inspect(error)}")
                {:halt, {:error, error}}
            end
          end)
        
        case tags do
          {:error, _} = error -> error
          tags -> {:ok, tags}
        end
      end
      
      defp route_message(message, metadata, state) do
        exchange = metadata.exchange
        routing_key = metadata.routing_key
        
        cond do
          String.contains?(exchange, "command") ->
            handle_command(message, metadata)
          
          String.contains?(exchange, "audit") ->
            handle_audit(message, metadata)
          
          String.contains?(exchange, "algedonic") ->
            handle_algedonic(message, metadata)
          
          String.contains?(exchange, "horizontal") ->
            handle_horizontal(message, metadata)
          
          String.contains?(exchange, "intel") ->
            handle_intel(message, metadata)
          
          true ->
            Logger.warn("Unknown message type from exchange: #{exchange}")
            :ok
        end
      end
      
      defp acknowledge_message(metadata, state) do
        AMQP.Basic.ack(state.channel, metadata.delivery_tag)
      end
      
      defp reject_message(metadata, state, opts \\ []) do
        requeue = Keyword.get(opts, :requeue, true)
        AMQP.Basic.reject(state.channel, metadata.delivery_tag, requeue: requeue)
      end
      
      defoverridable [
        handle_command: 2,
        handle_audit: 2,
        handle_algedonic: 2,
        handle_horizontal: 2,
        handle_intel: 2,
        default_subscriptions: 0
      ]
    end
  end
end