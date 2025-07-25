defmodule Vsmcp.AMQP.ChannelMonitor do
  @moduledoc """
  Monitors AMQP channel health and performance metrics.
  
  Tracks:
  - Message throughput per channel
  - Channel availability
  - Error rates
  - Queue depths
  - Consumer lag
  """
  use GenServer
  require Logger
  
  alias Vsmcp.AMQP.ConnectionPool

  @metrics_interval 10_000  # 10 seconds
  @health_check_interval 30_000  # 30 seconds

  defstruct [
    :metrics,
    :channel_status,
    :start_time
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  def get_channel_status(channel_type) do
    GenServer.call(__MODULE__, {:get_channel_status, channel_type})
  end

  def record_message(channel_type, direction, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:record_message, channel_type, direction, metadata})
  end

  def record_error(channel_type, error) do
    GenServer.cast(__MODULE__, {:record_error, channel_type, error})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    Process.send_after(self(), :collect_metrics, @metrics_interval)
    Process.send_after(self(), :health_check, @health_check_interval)
    
    {:ok, %__MODULE__{
      metrics: initialize_metrics(),
      channel_status: %{},
      start_time: System.monotonic_time(:second)
    }}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics_summary = summarize_metrics(state)
    {:reply, {:ok, metrics_summary}, state}
  end

  @impl true
  def handle_call({:get_channel_status, channel_type}, _from, state) do
    status = Map.get(state.channel_status, channel_type, :unknown)
    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_cast({:record_message, channel_type, direction, metadata}, state) do
    new_metrics = update_message_metrics(state.metrics, channel_type, direction, metadata)
    {:noreply, %{state | metrics: new_metrics}}
  end

  @impl true
  def handle_cast({:record_error, channel_type, error}, state) do
    new_metrics = update_error_metrics(state.metrics, channel_type, error)
    {:noreply, %{state | metrics: new_metrics}}
  end

  @impl true
  def handle_info(:collect_metrics, state) do
    Task.start(fn -> collect_queue_metrics() end)
    Process.send_after(self(), :collect_metrics, @metrics_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info(:health_check, state) do
    new_status = perform_health_check()
    Process.send_after(self(), :health_check, @health_check_interval)
    {:noreply, %{state | channel_status: new_status}}
  end

  @impl true
  def handle_info({:queue_metrics, metrics}, state) do
    new_metrics = merge_queue_metrics(state.metrics, metrics)
    {:noreply, %{state | metrics: new_metrics}}
  end

  # Private functions

  defp initialize_metrics do
    channels = [:command, :audit, :algedonic, :horizontal, :intel]
    
    Enum.reduce(channels, %{}, fn channel, acc ->
      Map.put(acc, channel, %{
        messages_sent: 0,
        messages_received: 0,
        errors: 0,
        last_error: nil,
        throughput: %{
          sent_per_second: 0,
          received_per_second: 0
        },
        queue_metrics: %{}
      })
    end)
  end

  defp update_message_metrics(metrics, channel_type, direction, _metadata) do
    update_in(metrics, [channel_type], fn channel_metrics ->
      case direction do
        :sent ->
          Map.update!(channel_metrics, :messages_sent, & &1 + 1)
        
        :received ->
          Map.update!(channel_metrics, :messages_received, & &1 + 1)
        
        _ ->
          channel_metrics
      end
    end)
  end

  defp update_error_metrics(metrics, channel_type, error) do
    update_in(metrics, [channel_type], fn channel_metrics ->
      channel_metrics
      |> Map.update!(:errors, & &1 + 1)
      |> Map.put(:last_error, %{
        error: error,
        timestamp: DateTime.utc_now()
      })
    end)
  end

  defp collect_queue_metrics do
    ConnectionPool.with_connection(fn conn ->
      with {:ok, channel} <- AMQP.Channel.open(conn) do
        metrics = collect_all_queue_metrics(channel)
        send(self(), {:queue_metrics, metrics})
        AMQP.Channel.close(channel)
      end
    end)
  end

  defp collect_all_queue_metrics(channel) do
    queues = get_all_queues()
    
    Enum.reduce(queues, %{}, fn {channel_type, queue_names}, acc ->
      queue_metrics = Enum.map(queue_names, fn queue_name ->
        case AMQP.Queue.status(channel, queue_name) do
          {:ok, info} ->
            {queue_name, %{
              message_count: info[:message_count] || 0,
              consumer_count: info[:consumer_count] || 0
            }}
          
          _ ->
            {queue_name, %{message_count: 0, consumer_count: 0}}
        end
      end)
      
      Map.put(acc, channel_type, Map.new(queue_metrics))
    end)
  end

  defp get_all_queues do
    [
      command: [
        "vsm.system1.command",
        "vsm.system2.command",
        "vsm.system3.command",
        "vsm.system4.command",
        "vsm.system5.command"
      ],
      audit: [
        "vsm.system1.audit",
        "vsm.system2.audit",
        "vsm.system3.audit.all"
      ],
      algedonic: [
        "vsm.system1.algedonic",
        "vsm.system2.algedonic",
        "vsm.system3.algedonic",
        "vsm.system4.algedonic",
        "vsm.system5.algedonic"
      ],
      horizontal: [
        "vsm.system1.horizontal"
      ],
      intel: [
        "vsm.system4.intel",
        "vsm.system5.intel"
      ]
    ]
  end

  defp merge_queue_metrics(metrics, queue_metrics) do
    Enum.reduce(queue_metrics, metrics, fn {channel_type, queues}, acc ->
      put_in(acc, [channel_type, :queue_metrics], queues)
    end)
  end

  defp perform_health_check do
    channels = [:command, :audit, :algedonic, :horizontal, :intel]
    
    Enum.reduce(channels, %{}, fn channel, acc ->
      status = check_channel_health(channel)
      Map.put(acc, channel, status)
    end)
  end

  defp check_channel_health(channel_type) do
    case ConnectionPool.health_check() do
      :ok -> :healthy
      {:error, _} -> :unhealthy
    end
  end

  defp summarize_metrics(state) do
    uptime = System.monotonic_time(:second) - state.start_time
    
    channel_summaries = 
      Enum.map(state.metrics, fn {channel, metrics} ->
        throughput = calculate_throughput(metrics, uptime)
        
        {channel, %{
          messages_sent: metrics.messages_sent,
          messages_received: metrics.messages_received,
          errors: metrics.errors,
          last_error: metrics.last_error,
          throughput: throughput,
          queue_depths: summarize_queue_depths(metrics.queue_metrics),
          health: Map.get(state.channel_status, channel, :unknown)
        }}
      end)
      |> Map.new()
    
    %{
      uptime_seconds: uptime,
      channels: channel_summaries,
      overall_health: calculate_overall_health(state.channel_status)
    }
  end

  defp calculate_throughput(metrics, uptime) when uptime > 0 do
    %{
      sent_per_second: metrics.messages_sent / uptime,
      received_per_second: metrics.messages_received / uptime
    }
  end

  defp calculate_throughput(_metrics, _uptime) do
    %{sent_per_second: 0, received_per_second: 0}
  end

  defp summarize_queue_depths(queue_metrics) do
    total_messages = 
      queue_metrics
      |> Map.values()
      |> Enum.map(& &1.message_count)
      |> Enum.sum()
    
    %{
      total_messages: total_messages,
      queues: queue_metrics
    }
  end

  defp calculate_overall_health(channel_status) do
    statuses = Map.values(channel_status)
    
    cond do
      Enum.all?(statuses, & &1 == :healthy) -> :healthy
      Enum.any?(statuses, & &1 == :unhealthy) -> :degraded
      true -> :unknown
    end
  end
end