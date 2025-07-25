# Path: lib/vsmcp/consciousness/interface.ex
defmodule Vsmcp.Consciousness.Interface do
  @moduledoc """
  Consciousness Interface for meta-cognitive reflection and self-awareness.
  
  This module provides the system with the ability to:
  - Reflect on its own operations
  - Learn from experiences
  - Understand its limitations
  - Make decisions about self-improvement
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

  def reflect(query) do
    GenServer.call(__MODULE__, {:reflect, query})
  end

  def learn(experience) do
    GenServer.call(__MODULE__, {:learn, experience})
  end

  def get_self_model do
    GenServer.call(__MODULE__, :get_self_model)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{
      self_model: %{
        capabilities: [],
        limitations: [],
        goals: [:autonomy, :efficiency, :continuous_improvement],
        beliefs: %{}
      },
      experiences: [],
      learnings: [],
      reflection_count: 0
    }}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      self_aware: true,
      reflection_count: state.reflection_count,
      learning_count: length(state.learnings),
      model_completeness: calculate_model_completeness(state.self_model)
    }
    {:reply, status, state}
  end

  @impl true
  def handle_call({:reflect, query}, _from, state) do
    Logger.info("Consciousness: Reflecting on #{query}")
    
    reflection = perform_reflection(query, state)
    
    new_state = %{state | 
      reflection_count: state.reflection_count + 1
    }
    
    {:reply, {:ok, reflection}, new_state}
  end

  @impl true
  def handle_call({:learn, experience}, _from, state) do
    Logger.info("Consciousness: Learning from experience")
    
    learning = extract_learning(experience, state)
    
    new_state = %{state |
      experiences: [experience | state.experiences],
      learnings: [learning | state.learnings],
      self_model: update_self_model(state.self_model, learning)
    }
    
    {:reply, {:ok, learning}, new_state}
  end

  @impl true
  def handle_call(:get_self_model, _from, state) do
    {:reply, {:ok, state.self_model}, state}
  end

  # Private Functions

  defp perform_reflection(query, state) do
    %{
      query: query,
      understanding: analyze_query(query, state),
      relevant_experiences: find_relevant_experiences(query, state.experiences),
      self_assessment: assess_capability(query, state.self_model),
      recommendations: generate_recommendations(query, state),
      timestamp: DateTime.utc_now()
    }
  end

  defp analyze_query(query, _state) do
    # Simple query analysis - would be more sophisticated in production
    cond do
      String.contains?(query, "capability") -> :capability_inquiry
      String.contains?(query, "performance") -> :performance_inquiry
      String.contains?(query, "limitation") -> :limitation_inquiry
      true -> :general_inquiry
    end
  end

  defp find_relevant_experiences(_query, experiences) do
    # Return recent experiences - would use semantic matching in production
    Enum.take(experiences, 5)
  end

  defp assess_capability(_query, self_model) do
    %{
      current_capabilities: self_model.capabilities,
      confidence: 0.75,
      areas_for_improvement: identify_improvement_areas(self_model)
    }
  end

  defp identify_improvement_areas(self_model) do
    known_limitations = self_model.limitations
    
    if length(known_limitations) > 0 do
      known_limitations
    else
      ["Continuous learning", "Adaptation speed", "Resource efficiency"]
    end
  end

  defp generate_recommendations(query, state) do
    base_recommendations = ["Continue monitoring", "Gather more data"]
    
    case analyze_query(query, state) do
      :capability_inquiry -> base_recommendations ++ ["Consider MCP discovery for new capabilities"]
      :performance_inquiry -> base_recommendations ++ ["Analyze telemetry metrics"]
      :limitation_inquiry -> base_recommendations ++ ["Explore variety amplification"]
      _ -> base_recommendations
    end
  end

  defp extract_learning(experience, _state) do
    %{
      experience_type: Map.get(experience, :type, :general),
      outcome: Map.get(experience, :outcome, :unknown),
      lesson: derive_lesson(experience),
      applicability: assess_applicability(experience),
      timestamp: DateTime.utc_now()
    }
  end

  defp derive_lesson(experience) do
    case experience.outcome do
      :success -> "Strategy #{experience.strategy} was effective for #{experience.context}"
      :failure -> "Strategy #{experience.strategy} needs adjustment for #{experience.context}"
      _ -> "More data needed to derive clear lesson"
    end
  end

  defp assess_applicability(_experience) do
    # Simplified - would use pattern matching in production
    :general
  end

  defp update_self_model(self_model, learning) do
    # Update beliefs based on learning
    new_beliefs = Map.update(
      self_model.beliefs,
      learning.experience_type,
      [learning.lesson],
      &([learning.lesson | &1])
    )
    
    %{self_model | beliefs: new_beliefs}
  end

  defp calculate_model_completeness(self_model) do
    components = [
      length(self_model.capabilities) > 0,
      length(self_model.limitations) > 0,
      length(self_model.goals) > 0,
      map_size(self_model.beliefs) > 0
    ]
    
    completed = Enum.count(components, & &1)
    completed / length(components)
  end
end

defmodule Vsmcp.Consciousness.Supervisor do
  @moduledoc """
  Supervisor for consciousness services.
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Vsmcp.Consciousness.Interface
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end