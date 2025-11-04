# Path: lib/vsmcp/core/variety_calculator.ex
defmodule Vsmcp.Core.VarietyCalculator do
  @moduledoc """
  Calculates variety (complexity) using Ashby's Law of Requisite Variety.
  
  Variety is the number of possible states a system can have.
  According to Ashby's Law, only variety can destroy variety.
  """
  use GenServer
  require Logger

  # Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the current variety calculation state.

  Returns operational variety, environmental variety, identified gaps,
  and historical data.
  """
  @spec current_state() :: map()
  def current_state do
    GenServer.call(__MODULE__, :current_state)
  end

  @doc """
  Analyze variety gaps and generate recommendations.

  Compares operational variety against environmental variety to identify
  deficits where the system cannot adequately absorb environmental complexity.

  ## Returns

  A tuple with `:ok` and a list of gap analysis maps, each containing:
  - Type of gap
  - Severity level
  - Gap magnitude
  - Recommendations for closing the gap
  """
  @spec analyze_gaps() :: {:ok, list(map())}
  def analyze_gaps do
    GenServer.call(__MODULE__, :analyze_gaps)
  end

  @doc """
  Calculate the current operational variety of the system.

  Operational variety is the number of distinct states the system can produce.
  """
  @spec calculate_operational_variety() :: {:ok, non_neg_integer()}
  def calculate_operational_variety do
    GenServer.call(__MODULE__, :calculate_operational)
  end

  @doc """
  Calculate the environmental variety the system must manage.

  Environmental variety is the complexity/number of distinct states
  in the environment that the system must respond to.
  """
  @spec calculate_environmental_variety() :: {:ok, non_neg_integer()}
  def calculate_environmental_variety do
    GenServer.call(__MODULE__, :calculate_environmental)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Schedule periodic variety checks
    :timer.send_interval(60_000, :check_variety)
    
    {:ok, %{
      operational_variety: 0,
      environmental_variety: 0,
      variety_gaps: [],
      history: []
    }}
  end

  @impl true
  def handle_call(:current_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:analyze_gaps, _from, state) do
    gaps = identify_variety_gaps(state)
    new_state = %{state | variety_gaps: gaps}
    {:reply, {:ok, gaps}, new_state}
  end

  @impl true
  def handle_call(:calculate_operational, _from, state) do
    variety = calculate_system_variety()
    new_state = %{state | operational_variety: variety}
    {:reply, {:ok, variety}, new_state}
  end

  @impl true
  def handle_call(:calculate_environmental, _from, state) do
    variety = calculate_environment_variety()
    new_state = %{state | environmental_variety: variety}
    {:reply, {:ok, variety}, new_state}
  end

  @impl true
  def handle_info(:check_variety, state) do
    Logger.debug("Performing periodic variety check")
    
    operational = calculate_system_variety()
    environmental = calculate_environment_variety()
    
    new_state = %{state |
      operational_variety: operational,
      environmental_variety: environmental,
      history: [{DateTime.utc_now(), operational, environmental} | state.history]
    }
    
    # Check if variety gap is significant
    if environmental > operational * 1.5 do
      Logger.warn("Significant variety gap detected: Op=#{operational}, Env=#{environmental}")
      Phoenix.PubSub.broadcast(Vsmcp.PubSub, "variety_alerts", {:variety_gap, environmental - operational})
    end
    
    {:noreply, new_state}
  end

  # Private Functions

  defp calculate_system_variety do
    # Calculate based on current system capabilities
    # This is a simplified calculation - real implementation would be more complex
    
    capabilities = get_system_capabilities()
    states_per_capability = 10 # Simplified assumption
    
    :math.pow(states_per_capability, length(capabilities))
    |> round()
  end

  defp calculate_environment_variety do
    # Calculate based on environmental demands
    # This is a simplified calculation
    
    environmental_factors = get_environmental_factors()
    states_per_factor = 15 # Environment is typically more complex
    
    :math.pow(states_per_factor, length(environmental_factors))
    |> round()
  end

  defp get_system_capabilities do
    # In real implementation, this would query actual system capabilities
    [:compute, :store, :communicate, :analyze, :decide]
  end

  defp get_environmental_factors do
    # In real implementation, this would analyze actual environment
    [:user_requests, :data_streams, :external_apis, :regulations, :competitors, :technology_changes]
  end

  defp identify_variety_gaps(state) do
    if state.environmental_variety > state.operational_variety do
      gap_ratio = state.environmental_variety / max(state.operational_variety, 1)
      
      [
        %{
          type: :variety_deficit,
          severity: categorize_severity(gap_ratio),
          operational: state.operational_variety,
          environmental: state.environmental_variety,
          gap: state.environmental_variety - state.operational_variety,
          recommendations: generate_recommendations(gap_ratio)
        }
      ]
    else
      []
    end
  end

  defp categorize_severity(ratio) do
    cond do
      ratio > 3.0 -> :critical
      ratio > 2.0 -> :high
      ratio > 1.5 -> :medium
      true -> :low
    end
  end

  defp generate_recommendations(ratio) do
    base_recommendations = [
      "Acquire new capabilities through MCP",
      "Implement variety amplifiers",
      "Reduce environmental complexity"
    ]
    
    if ratio > 2.0 do
      base_recommendations ++ ["Urgent: Consider system restructuring"]
    else
      base_recommendations
    end
  end
end