defmodule Vsmcp.Security.SecuritySupervisor do
  @moduledoc """
  Supervisor for all security and variety management components.
  
  Manages:
  - Z3N Zone Control
  - Neural Bloom Filter
  - Mria Wrapper
  - Autonomous Variety Manager
  """
  
  use Supervisor
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    children = [
      # Z3N Security Components
      {Vsmcp.Security.Z3nZoneControl, []},
      {Vsmcp.Security.NeuralBloomFilter, []},
      
      # Distributed Data Management
      {Vsmcp.Z3n.MriaWrapper, []},
      
      # Variety Management
      {Vsmcp.Variety.AutonomousManager, []},
      
      # Security Event Handler
      {Vsmcp.Security.EventHandler, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end