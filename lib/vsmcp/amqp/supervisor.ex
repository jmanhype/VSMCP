defmodule Vsmcp.AMQP.Supervisor do
  @moduledoc """
  Supervises all AMQP-related processes for the VSM nervous system.
  
  Child processes:
  - Connection pool
  - Channel manager
  - Channel monitor
  - System-specific consumers
  """
  use Supervisor
  
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Connection pool must start first
      Vsmcp.AMQP.ConnectionPool,
      
      # Channel manager handles exchange/queue setup
      Vsmcp.AMQP.ChannelManager,
      
      # Monitor tracks health and metrics
      Vsmcp.AMQP.ChannelMonitor,
      
      # System consumers (example - add all 5 systems)
      Vsmcp.AMQP.Consumers.System3Consumer
      
      # Add other system consumers as they are implemented:
      # Vsmcp.AMQP.Consumers.System1Consumer,
      # Vsmcp.AMQP.Consumers.System2Consumer,
      # Vsmcp.AMQP.Consumers.System4Consumer,
      # Vsmcp.AMQP.Consumers.System5Consumer
    ]

    # Use rest_for_one strategy so if connection pool fails,
    # all dependent processes are restarted
    Supervisor.init(children, strategy: :rest_for_one)
  end
end