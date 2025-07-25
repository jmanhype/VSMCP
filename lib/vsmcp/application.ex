# Path: lib/vsmcp/application.ex
defmodule Vsmcp.Application do
  @moduledoc """
  The VSMCP Application supervisor.
  
  This module starts the supervision tree for the Viable System Model
  with Model Context Protocol implementation.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      Vsmcp.Telemetry,
      
      # Start Phoenix PubSub for inter-system communication
      {Phoenix.PubSub, name: Vsmcp.PubSub},
      
      # Start the AMQP nervous system (must start before systems)
      Vsmcp.AMQP.Supervisor,
      
      # Start the CRDT subsystem for distributed state
      Vsmcp.CRDT.Supervisor,
      
      # Start the VSM Core supervisor
      Vsmcp.Supervisors.CoreSupervisor,
      
      # Start the System supervisors (System 1-5)
      Vsmcp.Systems.System1.Supervisor,
      Vsmcp.Systems.System2.Supervisor,
      Vsmcp.Systems.System3.Supervisor,
      Vsmcp.Systems.System4.Supervisor,
      Vsmcp.Systems.System5.Supervisor,
      
      # Start the Consciousness Interface
      Vsmcp.Consciousness.Supervisor,
      
      # Start the MCP subsystem
      Vsmcp.MCP.Supervisor,
      
      # Start the Integration Manager
      Vsmcp.Integration.Manager,
      
      # Start the Security and Variety Management supervisor
      Vsmcp.Security.SecuritySupervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Vsmcp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end