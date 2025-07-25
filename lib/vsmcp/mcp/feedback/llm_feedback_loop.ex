# Path: lib/vsmcp/mcp/feedback/llm_feedback_loop.ex
defmodule Vsmcp.MCP.Feedback.LLMFeedbackLoop do
  @moduledoc """
  Feedback loop mechanism that channels LLM insights from System 4
  back to System 3 for operational control adjustments.
  
  Implements the VSM principle of variety engineering through
  intelligent feedback and control adaptation.
  """
  
  use GenServer
  require Logger
  
  alias Vsmcp.Systems.{System3, System4}
  alias Vsmcp.MCP.Adapters.LLMAdapter
  alias Vsmcp.AMQP.Publisher
  
  # Feedback types
  defmodule Feedback do
    @enforce_keys [:id, :type, :source, :target, :content, :priority]
    defstruct [:id, :type, :source, :target, :content, :priority, :timestamp, :status, :metadata]
  end
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end
  
  def process_llm_insight(feedback_loop \\ __MODULE__, insight) do
    GenServer.call(feedback_loop, {:process_insight, insight})
  end
  
  def create_control_adjustment(feedback_loop \\ __MODULE__, analysis, target_system) do
    GenServer.call(feedback_loop, {:create_adjustment, analysis, target_system})
  end
  
  def enable_auto_feedback(feedback_loop \\ __MODULE__, enabled \\ true) do
    GenServer.call(feedback_loop, {:enable_auto_feedback, enabled})
  end
  
  def get_feedback_history(feedback_loop \\ __MODULE__, opts \\ []) do
    GenServer.call(feedback_loop, {:get_history, opts})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    # Subscribe to System 4 insights
    :ok = Publisher.subscribe("intelligence.insights")
    
    {:ok, %{
      feedbacks: [],
      auto_feedback: opts[:auto_feedback] || true,
      thresholds: %{
        critical: 0.9,
        high: 0.7,
        medium: 0.5
      },
      metrics: %{
        insights_processed: 0,
        adjustments_made: 0,
        feedback_sent: 0
      }
    }}
  end
  
  @impl true
  def handle_call({:process_insight, insight}, _from, state) do
    # Analyze insight for actionable feedback
    feedback_items = analyze_insight_for_feedback(insight)
    
    # Process each feedback item
    results = Enum.map(feedback_items, fn feedback ->
      process_feedback_item(feedback, state)
    end)
    
    # Update metrics
    new_metrics = %{state.metrics | 
      insights_processed: state.metrics.insights_processed + 1,
      feedback_sent: state.metrics.feedback_sent + length(feedback_items)
    }
    
    # Store feedback history
    new_feedbacks = feedback_items ++ state.feedbacks
    
    {:reply, {:ok, results}, %{state | 
      feedbacks: Enum.take(new_feedbacks, 100),
      metrics: new_metrics
    }}
  end
  
  @impl true
  def handle_call({:create_adjustment, analysis, target_system}, _from, state) do
    # Create control adjustment based on analysis
    adjustment = build_control_adjustment(analysis, target_system)
    
    # Send to System 3
    case send_to_system3(adjustment) do
      :ok ->
        new_metrics = %{state.metrics | adjustments_made: state.metrics.adjustments_made + 1}
        {:reply, {:ok, adjustment}, %{state | metrics: new_metrics}}
        
      error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:enable_auto_feedback, enabled}, _from, state) do
    {:reply, :ok, %{state | auto_feedback: enabled}}
  end
  
  @impl true
  def handle_call({:get_history, opts}, _from, state) do
    history = filter_feedback_history(state.feedbacks, opts)
    {:reply, history, state}
  end
  
  @impl true
  def handle_info({:intelligence_insight, insight}, state) do
    # Auto-process insights if enabled
    if state.auto_feedback do
      GenServer.call(self(), {:process_insight, insight})
    end
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp analyze_insight_for_feedback(insight) do
    feedbacks = []
    
    # Check for operational impacts
    feedbacks = feedbacks ++ analyze_operational_impacts(insight)
    
    # Check for control adjustments needed
    feedbacks = feedbacks ++ analyze_control_needs(insight)
    
    # Check for resource allocation changes
    feedbacks = feedbacks ++ analyze_resource_needs(insight)
    
    # Check for process improvements
    feedbacks = feedbacks ++ analyze_process_improvements(insight)
    
    feedbacks
  end
  
  defp analyze_operational_impacts(insight) do
    case insight do
      %{threats: threats} when is_list(threats) ->
        threats
        |> Enum.filter(&high_impact?/1)
        |> Enum.map(&create_threat_feedback/1)
        
      %{opportunities: opportunities} when is_list(opportunities) ->
        opportunities
        |> Enum.filter(&high_value?/1)
        |> Enum.map(&create_opportunity_feedback/1)
        
      _ ->
        []
    end
  end
  
  defp analyze_control_needs(insight) do
    case insight do
      %{variety_gap: gap} when gap.magnitude == :high ->
        [create_variety_adjustment_feedback(gap)]
        
      %{predictions: predictions} ->
        predictions
        |> Map.get(:trends, [])
        |> Enum.filter(&requires_control_change?/1)
        |> Enum.map(&create_control_feedback/1)
        
      _ ->
        []
    end
  end
  
  defp analyze_resource_needs(insight) do
    case insight do
      %{recommendations: recs} ->
        recs
        |> Enum.filter(&involves_resources?/1)
        |> Enum.map(&create_resource_feedback/1)
        
      _ ->
        []
    end
  end
  
  defp analyze_process_improvements(insight) do
    case insight do
      %{analysis: %{inefficiencies: inefficiencies}} ->
        inefficiencies
        |> Enum.map(&create_process_feedback/1)
        
      _ ->
        []
    end
  end
  
  defp high_impact?(threat) do
    impact = Map.get(threat, :impact, Map.get(threat, "impact", :medium))
    impact in [:high, :critical, "high", "critical"]
  end
  
  defp high_value?(opportunity) do
    value = Map.get(opportunity, :potential_value, Map.get(opportunity, "potential_value", 0))
    value > 0.7
  end
  
  defp requires_control_change?(trend) do
    confidence = Map.get(trend, :confidence, 0)
    direction = Map.get(trend, :direction, :stable)
    
    confidence > 0.7 && direction != :stable
  end
  
  defp involves_resources?(recommendation) do
    Map.has_key?(recommendation, :resource_requirements) ||
    Map.has_key?(recommendation, "resource_requirements")
  end
  
  defp create_threat_feedback(threat) do
    %Feedback{
      id: generate_feedback_id(),
      type: :threat_mitigation,
      source: :system4_llm,
      target: :system3,
      content: %{
        threat: threat,
        recommended_action: generate_threat_mitigation(threat)
      },
      priority: threat_to_priority(threat),
      timestamp: DateTime.utc_now(),
      status: :pending
    }
  end
  
  defp create_opportunity_feedback(opportunity) do
    %Feedback{
      id: generate_feedback_id(),
      type: :opportunity_exploitation,
      source: :system4_llm,
      target: :system3,
      content: %{
        opportunity: opportunity,
        recommended_action: generate_opportunity_action(opportunity)
      },
      priority: :high,
      timestamp: DateTime.utc_now(),
      status: :pending
    }
  end
  
  defp create_variety_adjustment_feedback(gap) do
    %Feedback{
      id: generate_feedback_id(),
      type: :variety_adjustment,
      source: :system4_llm,
      target: :system3,
      content: %{
        gap: gap,
        adjustment_needed: calculate_variety_adjustment(gap)
      },
      priority: :critical,
      timestamp: DateTime.utc_now(),
      status: :pending
    }
  end
  
  defp create_control_feedback(trend) do
    %Feedback{
      id: generate_feedback_id(),
      type: :control_adjustment,
      source: :system4_llm,
      target: :system3,
      content: %{
        trend: trend,
        control_changes: suggest_control_changes(trend)
      },
      priority: :medium,
      timestamp: DateTime.utc_now(),
      status: :pending
    }
  end
  
  defp create_resource_feedback(recommendation) do
    %Feedback{
      id: generate_feedback_id(),
      type: :resource_allocation,
      source: :system4_llm,
      target: :system3,
      content: %{
        recommendation: recommendation,
        resource_changes: extract_resource_changes(recommendation)
      },
      priority: :medium,
      timestamp: DateTime.utc_now(),
      status: :pending
    }
  end
  
  defp create_process_feedback(inefficiency) do
    %Feedback{
      id: generate_feedback_id(),
      type: :process_improvement,
      source: :system4_llm,
      target: :system3,
      content: %{
        inefficiency: inefficiency,
        improvement: suggest_process_improvement(inefficiency)
      },
      priority: :low,
      timestamp: DateTime.utc_now(),
      status: :pending
    }
  end
  
  defp generate_feedback_id do
    "feedback_#{:erlang.phash2(:erlang.unique_integer())}_#{System.os_time(:millisecond)}"
  end
  
  defp threat_to_priority(threat) do
    case Map.get(threat, :severity, Map.get(threat, "severity", :medium)) do
      s when s in [:critical, "critical"] -> :critical
      s when s in [:high, "high"] -> :high
      s when s in [:medium, "medium"] -> :medium
      _ -> :low
    end
  end
  
  defp generate_threat_mitigation(threat) do
    %{
      action: "Mitigate threat: #{threat[:description] || threat["description"] || "Unknown"}",
      steps: [
        "Assess current exposure",
        "Implement defensive measures",
        "Monitor for escalation"
      ],
      timeline: "Immediate"
    }
  end
  
  defp generate_opportunity_action(opportunity) do
    %{
      action: "Exploit opportunity: #{opportunity[:description] || opportunity["description"] || "Unknown"}",
      steps: [
        "Validate opportunity viability",
        "Allocate initial resources",
        "Execute pilot program"
      ],
      timeline: "2-4 weeks"
    }
  end
  
  defp calculate_variety_adjustment(gap) do
    %{
      required_variety_increase: gap[:magnitude] || :high,
      suggested_capabilities: gap[:missing_capabilities] || [],
      implementation_priority: :immediate
    }
  end
  
  defp suggest_control_changes(trend) do
    direction = trend[:direction] || :unknown
    
    case direction do
      :increasing ->
        %{
          adjustment: "Increase control sensitivity",
          parameters: ["threshold reduction", "faster response time"]
        }
        
      :decreasing ->
        %{
          adjustment: "Relax control constraints",
          parameters: ["threshold increase", "efficiency focus"]
        }
        
      _ ->
        %{
          adjustment: "Monitor closely",
          parameters: ["maintain current settings"]
        }
    end
  end
  
  defp extract_resource_changes(recommendation) do
    resources = recommendation[:resource_requirements] || 
                recommendation["resource_requirements"] || 
                %{}
    
    %{
      personnel: resources[:personnel] || resources["personnel"],
      budget: resources[:budget] || resources["budget"],
      tools: resources[:tools] || resources["tools"],
      priority: recommendation[:priority] || :medium
    }
  end
  
  defp suggest_process_improvement(inefficiency) do
    %{
      current_state: inefficiency[:description] || "Current process",
      improved_state: "Optimized process",
      expected_benefit: "20-30% efficiency gain",
      implementation: "Gradual rollout"
    }
  end
  
  defp process_feedback_item(feedback, state) do
    # Log the feedback
    Logger.info("Processing feedback: #{feedback.type} with priority #{feedback.priority}")
    
    # Route based on type and priority
    result = case feedback.priority do
      :critical ->
        # Immediate action required
        send_urgent_feedback(feedback)
        
      :high ->
        # Quick action needed
        send_priority_feedback(feedback)
        
      _ ->
        # Normal processing
        send_normal_feedback(feedback)
    end
    
    # Update feedback status
    %{feedback | status: :sent}
  end
  
  defp send_urgent_feedback(feedback) do
    # Send through algedonic channel for immediate attention
    Publisher.publish("algedonic", feedback.content, %{
      priority: :critical,
      source: :llm_feedback_loop,
      feedback_id: feedback.id
    })
    
    # Also send to System 3
    send_to_system3(feedback)
  end
  
  defp send_priority_feedback(feedback) do
    # Send through command channel
    Publisher.publish("command", feedback.content, %{
      priority: :high,
      source: :llm_feedback_loop,
      feedback_id: feedback.id
    })
    
    send_to_system3(feedback)
  end
  
  defp send_normal_feedback(feedback) do
    # Send through intelligence channel
    Publisher.publish("intelligence", feedback.content, %{
      priority: :normal,
      source: :llm_feedback_loop,
      feedback_id: feedback.id
    })
    
    send_to_system3(feedback)
  end
  
  defp send_to_system3(feedback) when is_struct(feedback, Feedback) do
    # Convert feedback to control adjustment
    adjustment = feedback_to_control_adjustment(feedback)
    System3.adjust_control(adjustment)
  end
  
  defp send_to_system3(adjustment) when is_map(adjustment) do
    System3.adjust_control(adjustment)
  end
  
  defp feedback_to_control_adjustment(feedback) do
    %{
      type: feedback.type,
      source: :llm_intelligence,
      parameters: extract_control_parameters(feedback),
      priority: feedback.priority,
      rationale: feedback.content
    }
  end
  
  defp extract_control_parameters(feedback) do
    case feedback.type do
      :threat_mitigation ->
        %{action: :tighten, focus: :security, intensity: :high}
        
      :opportunity_exploitation ->
        %{action: :adapt, focus: :growth, intensity: :medium}
        
      :variety_adjustment ->
        %{action: :expand, focus: :capabilities, intensity: :high}
        
      :control_adjustment ->
        feedback.content[:control_changes] || %{}
        
      :resource_allocation ->
        %{action: :reallocate, resources: feedback.content[:resource_changes]}
        
      :process_improvement ->
        %{action: :optimize, process: feedback.content[:improvement]}
        
      _ ->
        %{}
    end
  end
  
  defp build_control_adjustment(analysis, target_system) do
    %{
      target: target_system,
      adjustments: derive_adjustments_from_analysis(analysis),
      rationale: analysis[:summary] || "LLM-based analysis",
      confidence: analysis[:confidence] || 0.7,
      timestamp: DateTime.utc_now()
    }
  end
  
  defp derive_adjustments_from_analysis(analysis) do
    # Extract specific adjustments from analysis
    adjustments = []
    
    if analysis[:risks] do
      adjustments = adjustments ++ Enum.map(analysis.risks, &risk_to_adjustment/1)
    end
    
    if analysis[:improvements] do
      adjustments = adjustments ++ Enum.map(analysis.improvements, &improvement_to_adjustment/1)
    end
    
    if analysis[:recommendations] do
      adjustments = adjustments ++ Enum.map(analysis.recommendations, &recommendation_to_adjustment/1)
    end
    
    adjustments
  end
  
  defp risk_to_adjustment(risk) do
    %{
      type: :risk_mitigation,
      parameter: risk[:area] || "general",
      value: risk[:mitigation] || "monitor",
      priority: risk[:severity] || :medium
    }
  end
  
  defp improvement_to_adjustment(improvement) do
    %{
      type: :process_optimization,
      parameter: improvement[:process] || "general",
      value: improvement[:change] || "optimize",
      priority: :low
    }
  end
  
  defp recommendation_to_adjustment(recommendation) do
    %{
      type: :strategic_adjustment,
      parameter: recommendation[:area] || "general",
      value: recommendation[:action] || "adapt",
      priority: recommendation[:priority] || :medium
    }
  end
  
  defp filter_feedback_history(feedbacks, opts) do
    feedbacks
    |> maybe_filter_by_type(opts[:type])
    |> maybe_filter_by_priority(opts[:priority])
    |> maybe_filter_by_status(opts[:status])
    |> maybe_limit(opts[:limit])
  end
  
  defp maybe_filter_by_type(feedbacks, nil), do: feedbacks
  defp maybe_filter_by_type(feedbacks, type) do
    Enum.filter(feedbacks, &(&1.type == type))
  end
  
  defp maybe_filter_by_priority(feedbacks, nil), do: feedbacks
  defp maybe_filter_by_priority(feedbacks, priority) do
    Enum.filter(feedbacks, &(&1.priority == priority))
  end
  
  defp maybe_filter_by_status(feedbacks, nil), do: feedbacks
  defp maybe_filter_by_status(feedbacks, status) do
    Enum.filter(feedbacks, &(&1.status == status))
  end
  
  defp maybe_limit(feedbacks, nil), do: feedbacks
  defp maybe_limit(feedbacks, limit) do
    Enum.take(feedbacks, limit)
  end
end