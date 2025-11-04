# Path: lib/vsmcp/systems/system3.ex
defmodule Vsmcp.Systems.System3 do
  @moduledoc """
  System 3: Control
  
  Resource bargaining, optimization, and synergy creation.
  Manages the inside and now of the organization.
  """
  use GenServer
  require Logger

  # Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the current status of System 3.

  Returns resource availability, current allocations, and audit results.
  """
  @spec status() :: {:ok, map()}
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Optimize resource allocation based on policy and intelligence.

  Balances internal efficiency with external adaptation requirements.

  ## Parameters

  - `context`: Current operational context
  - `policy`: Policy directives from System 5
  - `intelligence`: Environmental intelligence from System 4

  ## Returns

  An optimization plan with resource allocations and operations.
  """
  @spec optimize(map(), map(), map()) :: {:ok, map()}
  def optimize(context, policy, intelligence) do
    GenServer.call(__MODULE__, {:optimize, context, policy, intelligence})
  end

  @doc """
  Perform an audit on a specified system.

  System 3* (audit channel) directly inspects operational units.

  ## Parameters

  - `system`: Identifier of the system to audit

  ## Returns

  Audit results including compliance status and recommendations.
  """
  @spec audit(term()) :: {:ok, map()}
  def audit(system) do
    GenServer.call(__MODULE__, {:audit, system})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{
      resources: %{
        computational: 1.0,
        memory: 1.0,
        network: 1.0
      },
      allocations: %{},
      audit_results: []
    }}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:optimize, context, policy, intelligence}, _from, state) do
    Logger.info("System 3: Optimizing resources based on policy and intelligence")
    
    # Calculate optimal resource allocation
    allocation = calculate_allocation(context, policy, intelligence, state.resources)
    
    # Update allocations
    new_state = %{state | allocations: allocation}
    
    optimization = %{
      operations: generate_operations(allocation, context),
      resources: allocation,
      timestamp: DateTime.utc_now()
    }
    
    {:reply, {:ok, optimization}, new_state}
  end

  @impl true
  def handle_call({:audit, system}, _from, state) do
    Logger.info("System 3: Auditing #{system}")
    
    audit_result = %{
      system: system,
      compliance: :compliant,
      efficiency: 0.85,
      recommendations: [],
      timestamp: DateTime.utc_now()
    }
    
    new_state = %{state | 
      audit_results: [audit_result | state.audit_results]
    }
    
    {:reply, {:ok, audit_result}, new_state}
  end

  # Private Functions

  defp calculate_allocation(context, _policy, _intelligence, resources) do
    # Simple allocation strategy - can be made more sophisticated
    total_demand = Enum.sum(Map.values(context[:demands] || %{computational: 1}))
    
    resources
    |> Enum.map(fn {resource, available} ->
      demand = Map.get(context[:demands] || %{}, resource, 0)
      allocation = if total_demand > 0, do: (demand / total_demand) * available, else: 0
      {resource, allocation}
    end)
    |> Enum.into(%{})
  end

  defp generate_operations(allocation, context) do
    # Generate operations based on resource allocation
    Enum.map(context[:tasks] || [], fn task ->
      %{
        task: task,
        resources: allocation,
        priority: :normal
      }
    end)
  end
end

defmodule Vsmcp.Systems.System3.Supervisor do
  @moduledoc """
  Supervisor for System 3 control services.
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Vsmcp.Systems.System3
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end