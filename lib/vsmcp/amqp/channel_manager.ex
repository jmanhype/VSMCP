defmodule Vsmcp.AMQP.ChannelManager do
  @moduledoc """
  Manages AMQP channels and ensures exchanges, queues, and bindings are properly configured.
  
  This module is responsible for:
  - Creating and maintaining VSM nervous system exchanges
  - Setting up queues for each system
  - Managing bindings between exchanges and queues
  - Channel lifecycle management
  """
  use GenServer
  require Logger
  
  alias Vsmcp.AMQP.{ConnectionPool, Config.ExchangeConfig}

  defstruct [:channels, :setup_complete]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_channel(channel_type) do
    GenServer.call(__MODULE__, {:get_channel, channel_type})
  end

  def publish(channel_type, exchange, routing_key, payload, options \\ []) do
    GenServer.call(__MODULE__, {:publish, channel_type, exchange, routing_key, payload, options})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)
    send(self(), :setup_infrastructure)
    {:ok, %__MODULE__{channels: %{}, setup_complete: false}}
  end

  @impl true
  def handle_info(:setup_infrastructure, state) do
    case setup_amqp_infrastructure() do
      :ok ->
        Logger.info("VSM AMQP infrastructure setup complete")
        {:noreply, %{state | setup_complete: true}}
      
      {:error, reason} ->
        Logger.error("Failed to setup AMQP infrastructure: #{inspect(reason)}")
        Process.send_after(self(), :setup_infrastructure, 5_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_call({:get_channel, channel_type}, _from, state) do
    case ensure_channel(channel_type, state) do
      {:ok, channel, new_state} ->
        {:reply, {:ok, channel}, new_state}
      
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:publish, channel_type, exchange, routing_key, payload, options}, _from, state) do
    result = 
      with {:ok, channel} <- ensure_channel(channel_type, state),
           :ok <- do_publish(channel, exchange, routing_key, payload, options) do
        :ok
      end
    
    {:reply, result, state}
  end

  # Private functions

  defp setup_amqp_infrastructure do
    ConnectionPool.with_connection(fn conn ->
      with {:ok, setup_channel} <- AMQP.Channel.open(conn),
           :ok <- setup_exchanges(setup_channel),
           :ok <- setup_queues(setup_channel),
           :ok <- setup_bindings(setup_channel) do
        AMQP.Channel.close(setup_channel)
        :ok
      end
    end)
  end

  defp setup_exchanges(channel) do
    exchanges = ExchangeConfig.exchanges()
    
    Enum.reduce_while(exchanges, :ok, fn {_name, config}, _acc ->
      case declare_exchange(channel, config) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp declare_exchange(channel, config) do
    options = [
      durable: config.durable,
      auto_delete: config.auto_delete,
      internal: config.internal
    ] ++ config.options
    
    case AMQP.Exchange.declare(channel, config.name, config.type, options) do
      :ok ->
        Logger.debug("Declared exchange: #{config.name}")
        :ok
      
      error ->
        Logger.error("Failed to declare exchange #{config.name}: #{inspect(error)}")
        error
    end
  end

  defp setup_queues(channel) do
    queues = ExchangeConfig.queues()
    
    Enum.reduce_while(queues, :ok, fn {system, queues}, _acc ->
      case setup_system_queues(channel, system, queues) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp setup_system_queues(channel, system, queue_config) do
    queue_config
    |> Map.delete(:options)
    |> Enum.reduce_while(:ok, fn {_type, queue_name}, _acc ->
      case declare_queue(channel, queue_name, queue_config.options) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp declare_queue(channel, queue_name, options) do
    case AMQP.Queue.declare(channel, queue_name, options) do
      {:ok, _} ->
        Logger.debug("Declared queue: #{queue_name}")
        :ok
      
      error ->
        Logger.error("Failed to declare queue #{queue_name}: #{inspect(error)}")
        error
    end
  end

  defp setup_bindings(channel) do
    with :ok <- setup_command_bindings(channel),
         :ok <- setup_audit_bindings(channel),
         :ok <- setup_algedonic_bindings(channel),
         :ok <- setup_horizontal_bindings(channel),
         :ok <- setup_intel_bindings(channel) do
      :ok
    end
  end

  defp setup_command_bindings(channel) do
    queues = ExchangeConfig.queues()
    
    # Bind command queues to command exchange with appropriate routing keys
    bindings = [
      {queues.system1.command, "system1.#"},
      {queues.system2.command, "system2.#"},
      {queues.system3.command, "system3.#"},
      {queues.system4.command, "system4.#"},
      {queues.system5.command, "system5.#"}
    ]
    
    bind_queues(channel, "vsm.command", bindings)
  end

  defp setup_audit_bindings(channel) do
    queues = ExchangeConfig.queues()
    
    # All audit messages go to all audit queues (fanout)
    bindings = [
      {queues.system1.audit, ""},
      {queues.system2.audit, ""},
      {queues.system3.audit, ""}  # System 3 gets all audit messages
    ]
    
    bind_queues(channel, "vsm.audit", bindings)
  end

  defp setup_algedonic_bindings(channel) do
    queues = ExchangeConfig.queues()
    
    # Direct routing for algedonic signals
    bindings = [
      {queues.system1.algedonic, "system1"},
      {queues.system2.algedonic, "system2"},
      {queues.system3.algedonic, "system3"},
      {queues.system4.algedonic, "system4"},
      {queues.system5.algedonic, "system5"}
    ]
    
    bind_queues(channel, "vsm.algedonic", bindings)
  end

  defp setup_horizontal_bindings(channel) do
    queues = ExchangeConfig.queues()
    
    # System 1 units can communicate horizontally
    bindings = [
      {queues.system1.horizontal, "*.*.*"}  # Receive all horizontal messages
    ]
    
    bind_queues(channel, "vsm.horizontal", bindings)
  end

  defp setup_intel_bindings(channel) do
    queues = ExchangeConfig.queues()
    
    # Intelligence goes to System 4 and System 5
    bindings = [
      {queues.system4.intel, "*.*.*"},  # System 4 gets all intel
      {queues.system5.intel, "*.*.urgent"}  # System 5 only gets urgent intel
    ]
    
    bind_queues(channel, "vsm.intel", bindings)
  end

  defp bind_queues(channel, exchange, bindings) do
    Enum.reduce_while(bindings, :ok, fn {queue, routing_key}, _acc ->
      case AMQP.Queue.bind(channel, queue, exchange, routing_key: routing_key) do
        :ok ->
          Logger.debug("Bound #{queue} to #{exchange} with key: #{routing_key}")
          {:cont, :ok}
        
        error ->
          Logger.error("Failed to bind #{queue} to #{exchange}: #{inspect(error)}")
          {:halt, error}
      end
    end)
  end

  defp ensure_channel(channel_type, state) do
    case Map.get(state.channels, channel_type) do
      nil ->
        open_channel(channel_type, state)
      
      channel ->
        # Check if channel is still alive
        if Process.alive?(channel.pid) do
          {:ok, channel, state}
        else
          open_channel(channel_type, state)
        end
    end
  end

  defp open_channel(channel_type, state) do
    ConnectionPool.with_connection(fn conn ->
      case AMQP.Channel.open(conn) do
        {:ok, channel} ->
          # Monitor the channel
          Process.monitor(channel.pid)
          new_channels = Map.put(state.channels, channel_type, channel)
          {:ok, channel, %{state | channels: new_channels}}
        
        error ->
          error
      end
    end)
  end

  defp do_publish(channel, exchange, routing_key, payload, options) do
    message = Jason.encode!(payload)
    
    publish_options = 
      options
      |> Keyword.put_new(:content_type, "application/json")
      |> Keyword.put_new(:persistent, true)
    
    AMQP.Basic.publish(channel, exchange, routing_key, message, publish_options)
  end
end