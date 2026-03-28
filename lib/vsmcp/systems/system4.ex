# Path: lib/vsmcp/systems/system4.ex
defmodule Vsmcp.Systems.System4 do
  @moduledoc """
  System 4: Intelligence
  
  Environmental scanning, future planning, and adaptation.
  Manages the outside and future of the organization.
  """
  use GenServer
  require Logger

  # Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the current status of System 4.

  Returns the environmental model, predictions, and adaptations.
  """
  @spec status() :: {:ok, map()}
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Scan the external environment for threats and opportunities.

  Analyzes the environment to detect changes, trends, and signals
  that may require organizational adaptation.

  ## Parameters

  - `context`: Environmental context to scan

  ## Returns

  Scan results including opportunities, threats, and trends.
  """
  @spec scan_environment(map()) :: {:ok, map()}
  def scan_environment(context) do
    GenServer.call(__MODULE__, {:scan_environment, context})
  end

  @doc """
  Predict future scenarios based on current trends.

  ## Parameters

  - `horizon`: Time horizon for predictions (e.g., :short, :medium, :long)

  ## Returns

  Future scenarios with probabilities.
  """
  @spec predict_future(term()) :: {:ok, map()}
  def predict_future(horizon) do
    GenServer.call(__MODULE__, {:predict_future, horizon})
  end

  @doc """
  Suggest adaptations in response to threats or opportunities.

  ## Parameters

  - `threat_or_opportunity`: A map describing the environmental change

  ## Returns

  Adaptation strategy with recommended actions.
  """
  @spec suggest_adaptation(map()) :: {:ok, map()}
  def suggest_adaptation(threat_or_opportunity) do
    GenServer.call(__MODULE__, {:suggest_adaptation, threat_or_opportunity})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{
      environmental_model: %{},
      predictions: [],
      adaptations: [],
      scanning_interval: 60_000 # 1 minute
    }}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:scan_environment, context}, _from, state) do
    Logger.info("System 4: Scanning environment")
    
    # Detect changes and trends
    scan_results = %{
      opportunities: detect_opportunities(context),
      threats: detect_threats(context),
      trends: analyze_trends(state.environmental_model, context),
      timestamp: DateTime.utc_now()
    }
    
    # Update environmental model
    new_model = update_model(state.environmental_model, scan_results)
    new_state = %{state | environmental_model: new_model}
    
    {:reply, {:ok, scan_results}, new_state}
  end

  @impl true
  def handle_call({:predict_future, horizon}, _from, state) do
    Logger.info("System 4: Predicting future for horizon: #{horizon}")
    
    prediction = %{
      horizon: horizon,
      scenarios: generate_scenarios(state.environmental_model, horizon),
      probabilities: calculate_probabilities(state.environmental_model),
      timestamp: DateTime.utc_now()
    }
    
    new_state = %{state | 
      predictions: [prediction | state.predictions]
    }
    
    {:reply, {:ok, prediction}, new_state}
  end

  @impl true
  def handle_call({:suggest_adaptation, item}, _from, state) do
    Logger.info("System 4: Suggesting adaptation for: #{inspect(item)}")
    
    adaptation = %{
      trigger: item,
      strategy: determine_strategy(item),
      actions: generate_actions(item),
      priority: assess_priority(item),
      timestamp: DateTime.utc_now()
    }
    
    new_state = %{state | 
      adaptations: [adaptation | state.adaptations]
    }
    
    {:reply, {:ok, adaptation}, new_state}
  end

  # Private Functions

  defp detect_opportunities(context) do
    # Identify opportunities from context
    context
    |> Map.get(:signals, [])
    |> Enum.filter(&(&1.type == :opportunity))
  end

  defp detect_threats(context) do
    # Identify threats from context
    context
    |> Map.get(:signals, [])
    |> Enum.filter(&(&1.type == :threat))
  end

  defp analyze_trends(model, context) do
    # Simple trend analysis
    %{
      growth_rate: Map.get(context, :growth_rate, 0),
      volatility: Map.get(context, :volatility, :low),
      direction: determine_direction(model, context)
    }
  end

  defp update_model(model, scan_results) do
    Map.merge(model, %{
      last_scan: scan_results,
      history: [scan_results | Map.get(model, :history, [])]
    })
  end

  defp generate_scenarios(_model, _horizon) do
    # Generate future scenarios
    [:optimistic, :realistic, :pessimistic]
  end

  defp calculate_probabilities(_model) do
    %{
      optimistic: 0.2,
      realistic: 0.6,
      pessimistic: 0.2
    }
  end

  defp determine_strategy(item) do
    case item.type do
      :opportunity -> :exploit
      :threat -> :mitigate
      _ -> :monitor
    end
  end

  defp generate_actions(item) do
    case item.type do
      :opportunity -> [:investigate, :allocate_resources, :quick_win]
      :threat -> [:defend, :diversify, :prepare_contingency]
      _ -> [:monitor, :analyze]
    end
  end

  defp assess_priority(item) do
    case item.impact do
      :high -> :critical
      :medium -> :important
      :low -> :routine
      _ -> :normal
    end
  end

  defp determine_direction(_model, _context) do
    :stable # Simplified - would use historical data
  end
end

defmodule Vsmcp.Systems.System4.Supervisor do
  @moduledoc """
  Supervisor for System 4 intelligence services.
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Vsmcp.Systems.System4
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end