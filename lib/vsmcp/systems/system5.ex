# Path: lib/vsmcp/systems/system5.ex
defmodule Vsmcp.Systems.System5 do
  @moduledoc """
  System 5: Policy
  
  Identity, ethos, and ultimate authority.
  Balances the inside/now (System 3) with outside/future (System 4).
  """
  use GenServer
  require Logger

  # Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the current status of System 5.

  Returns the system identity, active policies, and decision history.
  """
  @spec status() :: {:ok, map()}
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Get applicable policies for a given context.

  Determines which policies apply and how they should be interpreted
  based on the current context and system identity.

  ## Parameters

  - `context`: Operational context requiring policy guidance

  ## Returns

  Applicable policies with identity and constraints.
  """
  @spec get_policy(map()) :: {:ok, map()}
  def get_policy(context) do
    GenServer.call(__MODULE__, {:get_policy, context})
  end

  @doc """
  Update the system's identity.

  Modifies the core identity attributes including purpose, values,
  and constraints.

  ## Parameters

  - `identity`: Map containing identity attributes to merge

  ## Returns

  `:ok` on success
  """
  @spec set_identity(map()) :: :ok
  def set_identity(identity) do
    GenServer.call(__MODULE__, {:set_identity, identity})
  end

  @doc """
  Make a strategic decision balancing internal and external perspectives.

  This is the ultimate authority in the VSM, balancing System 3's
  internal optimization with System 4's external adaptation.

  ## Parameters

  - `issue`: Description of the strategic issue
  - `s3_input`: Internal perspective from System 3
  - `s4_input`: External perspective from System 4

  ## Returns

  Strategic decision with rationale and action plan.
  """
  @spec make_strategic_decision(String.t(), map(), map()) :: {:ok, map()}
  def make_strategic_decision(issue, s3_input, s4_input) do
    GenServer.call(__MODULE__, {:strategic_decision, issue, s3_input, s4_input})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{
      identity: %{
        purpose: "Autonomous cybernetic system with self-improvement",
        values: [:autonomy, :efficiency, :learning, :adaptation],
        constraints: [:ethical_ai, :resource_limits, :safety]
      },
      policies: %{
        resource_allocation: :balanced,
        growth_strategy: :sustainable,
        risk_tolerance: :moderate,
        learning_rate: 0.1
      },
      decisions: []
    }}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:get_policy, context}, _from, state) do
    Logger.info("System 5: Determining policy for context")
    
    policy = %{
      identity: state.identity,
      policies: apply_contextual_policies(state.policies, context),
      timestamp: DateTime.utc_now()
    }
    
    {:reply, {:ok, policy}, state}
  end

  @impl true
  def handle_call({:set_identity, identity}, _from, state) do
    Logger.info("System 5: Updating system identity")
    
    new_state = %{state | identity: Map.merge(state.identity, identity)}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:strategic_decision, issue, s3_input, s4_input}, _from, state) do
    Logger.info("System 5: Making strategic decision on: #{issue}")
    
    # Balance internal efficiency (S3) with external adaptation (S4)
    decision = %{
      issue: issue,
      s3_perspective: s3_input,
      s4_perspective: s4_input,
      resolution: balance_perspectives(s3_input, s4_input, state.policies),
      rationale: generate_rationale(issue, s3_input, s4_input),
      timestamp: DateTime.utc_now()
    }
    
    new_state = %{state | 
      decisions: [decision | state.decisions]
    }
    
    {:reply, {:ok, decision}, new_state}
  end

  # Private Functions

  defp apply_contextual_policies(policies, context) do
    # Adjust policies based on context
    cond do
      context[:crisis] -> Map.put(policies, :risk_tolerance, :conservative)
      context[:opportunity] -> Map.put(policies, :growth_strategy, :aggressive)
      true -> policies
    end
  end

  defp balance_perspectives(s3_input, s4_input, policies) do
    # Decision logic balancing internal and external perspectives
    s3_weight = case policies.growth_strategy do
      :conservative -> 0.7
      :balanced -> 0.5
      :aggressive -> 0.3
    end
    
    s4_weight = 1.0 - s3_weight
    
    %{
      action: determine_action(s3_input, s4_input, s3_weight, s4_weight),
      s3_weight: s3_weight,
      s4_weight: s4_weight
    }
  end

  defp determine_action(s3_input, s4_input, s3_weight, s4_weight) do
    # Weighted decision making
    if s3_weight > s4_weight do
      s3_input[:recommendation] || :optimize_internal
    else
      s4_input[:recommendation] || :adapt_external
    end
  end

  defp generate_rationale(issue, s3_input, s4_input) do
    """
    Strategic decision for #{issue}:
    - Internal perspective (S3): #{inspect(s3_input[:summary])}
    - External perspective (S4): #{inspect(s4_input[:summary])}
    - Decision based on current identity and policies
    """
  end
end

defmodule Vsmcp.Systems.System5.Supervisor do
  @moduledoc """
  Supervisor for System 5 policy services.
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Vsmcp.Systems.System5
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end