# Path: lib/vsmcp/systems/system1.ex
defmodule Vsmcp.Systems.System1 do
  @moduledoc """
  System 1: Operations
  
  The operational units that perform the primary activities of the organization.
  Each operational unit is autonomous but connected to the larger system.
  """
  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  def execute(coordination) do
    GenServer.call(__MODULE__, {:execute, coordination})
  end

  def register_capability(name, handler) do
    GenServer.call(__MODULE__, {:register_capability, name, handler})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{
      operations: %{},
      capabilities: %{},
      metrics: %{
        executions: 0,
        successes: 0,
        failures: 0
      }
    }}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:execute, coordination}, _from, state) do
    Logger.info("System 1: Executing coordination plan")
    
    # Execute operations based on coordination
    result = perform_operations(coordination, state.capabilities)
    
    # Update metrics
    new_state = update_metrics(state, result)
    
    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:register_capability, name, handler}, _from, state) do
    new_capabilities = Map.put(state.capabilities, name, handler)
    {:reply, :ok, %{state | capabilities: new_capabilities}}
  end

  # Private Functions

  defp perform_operations(coordination, capabilities) do
    coordination
    |> Map.get(:operations, [])
    |> Enum.map(fn op ->
      case Map.get(capabilities, op.capability) do
        nil -> {:error, {:missing_capability, op.capability}}
        handler -> handler.(op)
      end
    end)
  end

  defp update_metrics(state, results) do
    successes = Enum.count(results, &match?({:ok, _}, &1))
    failures = length(results) - successes
    
    %{state | 
      metrics: %{
        executions: state.metrics.executions + length(results),
        successes: state.metrics.successes + successes,
        failures: state.metrics.failures + failures
      }
    }
  end
end

defmodule Vsmcp.Systems.System1.Supervisor do
  @moduledoc """
  Supervisor for System 1 operational units.
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Vsmcp.Systems.System1
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end