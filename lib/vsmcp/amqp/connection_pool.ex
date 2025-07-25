defmodule Vsmcp.AMQP.ConnectionPool do
  @moduledoc """
  Manages AMQP connection pooling for the VSM nervous system.
  
  Provides resilient connections with automatic recovery and health monitoring.
  """
  use Supervisor
  require Logger
  
  alias Vsmcp.AMQP.Config.ExchangeConfig

  @pool_name :vsm_amqp_pool

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    pool_config = ExchangeConfig.connection_pool_config()
    
    children = [
      :poolboy.child_spec(
        @pool_name,
        pool_options(pool_config),
        worker_options(pool_config)
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Checkout a connection from the pool and execute a function
  """
  def with_connection(fun) when is_function(fun, 1) do
    :poolboy.transaction(@pool_name, fn worker ->
      GenServer.call(worker, {:with_connection, fun})
    end, :infinity)
  rescue
    error ->
      Logger.error("Connection pool error: #{inspect(error)}")
      {:error, error}
  end

  @doc """
  Get pool status
  """
  def status do
    %{
      pool_size: :poolboy.status(@pool_name),
      workers: get_worker_status()
    }
  end

  @doc """
  Health check for the connection pool
  """
  def health_check do
    with_connection(fn conn ->
      case AMQP.Connection.status(conn) do
        :open -> :ok
        status -> {:error, status}
      end
    end)
  end

  # Private functions

  defp pool_options(config) do
    [
      name: {:local, @pool_name},
      worker_module: Vsmcp.AMQP.ConnectionWorker,
      size: config.size,
      max_overflow: config.max_overflow,
      strategy: config.strategy
    ]
  end

  defp worker_options(config) do
    config.connection_opts
  end

  defp get_worker_status do
    :poolboy.status(@pool_name)
    |> Map.new(fn {key, value} -> {key, value} end)
  end
end

defmodule Vsmcp.AMQP.ConnectionWorker do
  @moduledoc """
  Worker process that maintains an AMQP connection.
  """
  use GenServer
  require Logger

  defstruct [:connection, :monitor_ref, :connection_opts, :reconnect_interval]

  def start_link(connection_opts) do
    GenServer.start_link(__MODULE__, connection_opts)
  end

  @impl true
  def init(connection_opts) do
    Process.flag(:trap_exit, true)
    state = %__MODULE__{
      connection_opts: connection_opts,
      reconnect_interval: 5_000
    }
    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case establish_connection(state.connection_opts) do
      {:ok, conn} ->
        monitor_ref = Process.monitor(conn.pid)
        {:noreply, %{state | connection: conn, monitor_ref: monitor_ref}}
      
      {:error, reason} ->
        Logger.error("Failed to connect to RabbitMQ: #{inspect(reason)}")
        Process.send_after(self(), :reconnect, state.reconnect_interval)
        {:noreply, state}
    end
  end

  @impl true
  def handle_call({:with_connection, fun}, _from, %{connection: nil} = state) do
    {:reply, {:error, :no_connection}, state}
  end

  @impl true
  def handle_call({:with_connection, fun}, _from, state) do
    result = 
      try do
        fun.(state.connection)
      rescue
        error -> {:error, error}
      end
    
    {:reply, result, state}
  end

  @impl true
  def handle_info(:reconnect, state) do
    {:noreply, state, {:continue, :connect}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{monitor_ref: ref} = state) do
    Logger.warn("AMQP connection lost: #{inspect(reason)}")
    Process.send_after(self(), :reconnect, state.reconnect_interval)
    {:noreply, %{state | connection: nil, monitor_ref: nil}}
  end

  @impl true
  def terminate(_reason, %{connection: conn}) when not is_nil(conn) do
    AMQP.Connection.close(conn)
  catch
    _, _ -> :ok
  end

  def terminate(_reason, _state), do: :ok

  # Private functions

  defp establish_connection(opts) do
    connection_params = 
      opts
      |> Keyword.take([:host, :port, :username, :password, :virtual_host, :heartbeat, :connection_timeout])
      |> Enum.into(%{})
    
    case AMQP.Connection.open(connection_params) do
      {:ok, conn} ->
        Logger.info("Successfully connected to RabbitMQ at #{opts[:host]}:#{opts[:port]}")
        {:ok, conn}
      
      error ->
        error
    end
  end
end