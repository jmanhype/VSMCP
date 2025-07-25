defmodule VsmcpWeb.Telemetry do
  @moduledoc """
  Phoenix telemetry instrumentation for VSMCP web interface.
  
  Provides metrics for:
  - HTTP request tracking
  - LiveView performance
  - WebSocket connections
  - API endpoint usage
  """
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms for web-specific metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond},
        tags: [:method, :route]
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:method, :route],
        unit: {:native, :millisecond}
      ),
      counter("phoenix.router_dispatch.stop.count",
        tags: [:method, :route]
      ),
      
      # LiveView Metrics
      summary("phoenix.live_view.mount.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view]
      ),
      summary("phoenix.live_view.handle_event.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view, :event]
      ),
      counter("phoenix.live_view.handle_event.stop.count",
        tags: [:view, :event]
      ),
      
      # WebSocket Metrics
      counter("phoenix.channel_joined.count",
        tags: [:channel]
      ),
      counter("phoenix.channel_handled_in.count",
        tags: [:channel, :event]
      ),
      
      # VSM Web Interface Metrics
      counter("vsmcp.web.system_view.count",
        tags: [:system]
      ),
      counter("vsmcp.web.visualization.rendered",
        tags: [:type]
      ),
      counter("vsmcp.web.api.calls",
        tags: [:endpoint, :method]
      ),
      counter("vsmcp.web.errors",
        tags: [:type, :route]
      ),
      
      # Real-time Updates
      counter("vsmcp.web.pubsub.messages",
        tags: [:topic]
      ),
      summary("vsmcp.web.pubsub.latency",
        unit: {:native, :millisecond},
        tags: [:topic]
      ),
      
      # Resource Usage
      last_value("vsmcp.web.connections.active"),
      last_value("vsmcp.web.websockets.active"),
      last_value("vsmcp.web.liveviews.active"),
      
      # Performance Metrics
      summary("vsmcp.web.page_load.duration",
        unit: {:native, :millisecond},
        tags: [:page]
      ),
      summary("vsmcp.web.api.response_time",
        unit: {:native, :millisecond},
        tags: [:endpoint]
      )
    ]
  end

  defp periodic_measurements do
    [
      # Web-specific periodic measurements
      {__MODULE__, :emit_connection_metrics, []},
      {__MODULE__, :emit_performance_metrics, []}
    ]
  end

  def emit_connection_metrics do
    # Get active connections from Phoenix endpoint
    connections = 
      case Process.whereis(VsmcpWeb.Endpoint) do
        nil -> 0
        pid -> 
          # This is a simplified example - actual implementation would
          # query the endpoint's connection tracking
          :sys.get_state(pid)
          |> get_in([:conn_tracker, :active])
          |> Kernel.||(0)
      end

    :telemetry.execute(
      [:vsmcp, :web, :connections],
      %{active: connections},
      %{}
    )
  end

  def emit_performance_metrics do
    # Emit web performance metrics
    # This could track things like average response times,
    # active LiveViews, etc.
    :telemetry.execute(
      [:vsmcp, :web, :performance],
      %{
        liveviews_active: 0,  # Would be tracked by LiveView telemetry
        websockets_active: 0  # Would be tracked by channel telemetry
      },
      %{}
    )
  end

  @doc """
  Attaches telemetry handlers for web interface monitoring.
  Should be called during application startup.
  """
  def attach_handlers do
    # Attach Phoenix-specific handlers
    :telemetry.attach(
      "vsmcp-web-request-logger",
      [:phoenix, :endpoint, :stop],
      &__MODULE__.handle_endpoint_stop/4,
      nil
    )

    :telemetry.attach(
      "vsmcp-web-error-logger",
      [:phoenix, :endpoint, :error],
      &__MODULE__.handle_endpoint_error/4,
      nil
    )

    :telemetry.attach(
      "vsmcp-web-liveview-logger",
      [:phoenix, :live_view, :mount, :stop],
      &__MODULE__.handle_liveview_mount/4,
      nil
    )
  end

  def handle_endpoint_stop(_event_name, measurements, metadata, _config) do
    # Log HTTP request completions
    duration = measurements.duration
    status = metadata.conn.status
    method = metadata.conn.method
    path = metadata.conn.request_path

    if status >= 400 do
      :telemetry.execute(
        [:vsmcp, :web, :errors],
        %{count: 1},
        %{type: "http_#{status}", route: path}
      )
    end

    # Could add more detailed logging here
  end

  def handle_endpoint_error(_event_name, _measurements, metadata, _config) do
    # Log endpoint errors
    :telemetry.execute(
      [:vsmcp, :web, :errors],
      %{count: 1},
      %{type: "endpoint_error", route: metadata.conn.request_path}
    )
  end

  def handle_liveview_mount(_event_name, measurements, metadata, _config) do
    # Track LiveView mounts
    :telemetry.execute(
      [:vsmcp, :web, :system_view],
      %{count: 1},
      %{system: metadata.socket.view |> Module.split() |> List.last()}
    )
  end
end