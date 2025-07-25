# Path: lib/vsmcp/supervisors/core_supervisor.ex
defmodule Vsmcp.Supervisors.CoreSupervisor do
  @moduledoc """
  Core supervisor for essential VSMCP services.
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Core services
      Vsmcp.Core.VarietyCalculator,
      
      # Additional core services can be added here
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end