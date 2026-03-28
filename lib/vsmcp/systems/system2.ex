# Path: lib/vsmcp/systems/system2.ex
defmodule Vsmcp.Systems.System2 do
  @moduledoc """
  System 2: Coordination
  
  Anti-oscillation and conflict resolution between operational units.
  Ensures smooth coordination and prevents destructive interference.
  """
  use GenServer
  require Logger

  # Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the current status of System 2.

  Returns coordination rules, active coordinations, and conflict history.
  """
  @spec status() :: {:ok, map()}
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Coordinate an optimization plan from System 3.

  Applies coordination rules and anti-oscillation logic to ensure
  smooth execution across operational units.
  """
  @spec coordinate(map()) :: {:ok, map()}
  def coordinate(optimization) do
    GenServer.call(__MODULE__, {:coordinate, optimization})
  end

  @doc """
  Resolve conflicts between operational units.

  ## Parameters

  - `unit1`: Identifier for first operational unit
  - `unit2`: Identifier for second operational unit
  - `issue`: Atom describing the type of conflict

  ## Returns

  A resolution map containing the resolution strategy and actions.
  """
  @spec resolve_conflict(term(), term(), atom()) :: {:ok, map()}
  def resolve_conflict(unit1, unit2, issue) do
    GenServer.call(__MODULE__, {:resolve_conflict, unit1, unit2, issue})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{
      coordination_rules: %{},
      active_coordinations: [],
      conflict_history: []
    }}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:coordinate, optimization}, _from, state) do
    Logger.info("System 2: Coordinating optimization plan")
    
    # Apply coordination rules
    coordinated_plan = apply_coordination_rules(optimization, state.coordination_rules)
    
    # Track active coordination
    new_state = %{state | 
      active_coordinations: [coordinated_plan | state.active_coordinations]
    }
    
    {:reply, {:ok, coordinated_plan}, new_state}
  end

  @impl true
  def handle_call({:resolve_conflict, unit1, unit2, issue}, _from, state) do
    Logger.info("System 2: Resolving conflict between #{unit1} and #{unit2}")
    
    resolution = %{
      units: [unit1, unit2],
      issue: issue,
      resolution: determine_resolution(issue),
      timestamp: DateTime.utc_now()
    }
    
    new_state = %{state | 
      conflict_history: [resolution | state.conflict_history]
    }
    
    {:reply, {:ok, resolution}, new_state}
  end

  # Private Functions

  defp apply_coordination_rules(optimization, rules) do
    %{
      operations: optimization.operations,
      coordinated: true,
      rules_applied: Map.keys(rules)
    }
  end

  defp determine_resolution(issue) do
    # Simple resolution logic - can be expanded
    case issue do
      :resource_conflict -> :time_sharing
      :priority_conflict -> :weighted_priority
      _ -> :arbitration
    end
  end
end

defmodule Vsmcp.Systems.System2.Supervisor do
  @moduledoc """
  Supervisor for System 2 coordination services.
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Vsmcp.Systems.System2
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end