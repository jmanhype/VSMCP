defmodule VsmcpWeb.VarietyController do
  use VsmcpWeb, :controller

  alias Vsmcp.Core.VarietyCalculator
  alias Vsmcp.Variety.AutonomousManager

  def index(conn, _params) do
    # Get variety metrics and analysis
    current_variety = get_current_variety()
    variety_gaps = analyze_variety_gaps()
    attenuation_amplification = get_attenuation_amplification()
    historical_data = get_variety_history()

    render(conn, :index,
      current_variety: current_variety,
      variety_gaps: variety_gaps,
      attenuation_amplification: attenuation_amplification,
      historical_data: historical_data
    )
  end

  def analysis(conn, %{"scope" => scope} = params) do
    analysis_result = perform_variety_analysis(scope, params)
    
    render(conn, :analysis,
      result: analysis_result,
      recommendations: generate_recommendations(analysis_result)
    )
  end

  def gaps(conn, _params) do
    detailed_gaps = get_detailed_variety_gaps()
    mitigation_strategies = get_mitigation_strategies()
    
    render(conn, :gaps,
      gaps: detailed_gaps,
      strategies: mitigation_strategies
    )
  end

  def attenuators(conn, _params) do
    active_attenuators = get_active_attenuators()
    available_attenuators = get_available_attenuators()
    
    render(conn, :attenuators,
      active: active_attenuators,
      available: available_attenuators
    )
  end

  def amplifiers(conn, _params) do
    active_amplifiers = get_active_amplifiers()
    available_amplifiers = get_available_amplifiers()
    
    render(conn, :amplifiers,
      active: active_amplifiers,
      available: available_amplifiers
    )
  end

  def balance(conn, %{"action" => action} = params) do
    case execute_balance_action(action, params) do
      {:ok, result} ->
        conn
        |> put_flash(:info, "Variety balance action executed: #{action}")
        |> json(%{success: true, result: result})
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, error: to_string(reason)})
    end
  end

  defp get_current_variety do
    try do
      GenServer.call(VarietyCalculator, :get_current_variety, 5000)
    catch
      :exit, _ -> 
        %{
          environmental: 0.85,
          system: 0.72,
          requisite: 0.80,
          gap: 0.08,
          trend: :increasing
        }
    end
  end

  defp analyze_variety_gaps do
    [
      %{
        subsystem: "System 1",
        environmental_variety: 0.9,
        system_variety: 0.75,
        gap: 0.15,
        status: :attention_needed
      },
      %{
        subsystem: "System 2",
        environmental_variety: 0.7,
        system_variety: 0.68,
        gap: 0.02,
        status: :acceptable
      },
      %{
        subsystem: "System 3",
        environmental_variety: 0.8,
        system_variety: 0.78,
        gap: 0.02,
        status: :acceptable
      },
      %{
        subsystem: "System 4",
        environmental_variety: 0.95,
        system_variety: 0.82,
        gap: 0.13,
        status: :attention_needed
      },
      %{
        subsystem: "System 5",
        environmental_variety: 0.6,
        system_variety: 0.65,
        gap: -0.05,
        status: :over_controlled
      }
    ]
  end

  defp get_attenuation_amplification do
    %{
      attenuators: [
        %{name: "Standardization", effectiveness: 0.85, status: :active},
        %{name: "Filtering", effectiveness: 0.72, status: :active},
        %{name: "Aggregation", effectiveness: 0.90, status: :active}
      ],
      amplifiers: [
        %{name: "Automation", effectiveness: 0.88, status: :active},
        %{name: "Delegation", effectiveness: 0.75, status: :partial},
        %{name: "Tool Integration", effectiveness: 0.82, status: :active}
      ]
    }
  end

  defp get_variety_history do
    # Generate historical variety data for visualization
    for i <- 0..23 do
      timestamp = DateTime.add(DateTime.utc_now(), -i * 3600, :second)
      %{
        timestamp: timestamp,
        environmental: 0.8 + :rand.uniform() * 0.2,
        system: 0.7 + :rand.uniform() * 0.2,
        gap: -0.1 + :rand.uniform() * 0.2
      }
    end
    |> Enum.reverse()
  end

  defp perform_variety_analysis(scope, params) do
    %{
      scope: scope,
      timestamp: DateTime.utc_now(),
      findings: %{
        major_gaps: :rand.uniform(3),
        opportunities: :rand.uniform(5),
        risks: :rand.uniform(2)
      },
      metrics: %{
        overall_balance: 0.82,
        stability: 0.88,
        adaptability: 0.75
      }
    }
  end

  defp generate_recommendations(analysis_result) do
    [
      %{
        priority: :high,
        action: "Implement additional attenuators in System 1",
        expected_impact: "Reduce variety gap by 0.08",
        effort: :medium
      },
      %{
        priority: :medium,
        action: "Enhance amplification in System 4",
        expected_impact: "Improve environmental scanning by 15%",
        effort: :high
      },
      %{
        priority: :low,
        action: "Fine-tune System 5 controls",
        expected_impact: "Reduce over-control by 0.05",
        effort: :low
      }
    ]
  end

  defp get_detailed_variety_gaps do
    # Detailed gap analysis with root causes
    analyze_variety_gaps()
    |> Enum.map(fn gap ->
      Map.merge(gap, %{
        root_causes: identify_root_causes(gap),
        impact_assessment: assess_impact(gap),
        priority: calculate_priority(gap)
      })
    end)
  end

  defp get_mitigation_strategies do
    %{
      immediate: [
        "Deploy emergency attenuators for System 1",
        "Activate backup amplification channels"
      ],
      short_term: [
        "Implement automated filtering rules",
        "Enhance delegation protocols"
      ],
      long_term: [
        "Redesign information architecture",
        "Develop adaptive variety management system"
      ]
    }
  end

  defp get_active_attenuators do
    [
      %{id: "att-001", name: "Input Filter", type: :automatic, load: 0.75},
      %{id: "att-002", name: "Report Aggregator", type: :manual, load: 0.60},
      %{id: "att-003", name: "Exception Handler", type: :automatic, load: 0.85}
    ]
  end

  defp get_available_attenuators do
    [
      %{id: "att-004", name: "Pattern Matcher", type: :ai_powered, capacity: 0.90},
      %{id: "att-005", name: "Threshold Filter", type: :rule_based, capacity: 0.80},
      %{id: "att-006", name: "Batch Processor", type: :scheduled, capacity: 0.95}
    ]
  end

  defp get_active_amplifiers do
    [
      %{id: "amp-001", name: "MCP Tools", type: :integration, utilization: 0.82},
      %{id: "amp-002", name: "Automation Suite", type: :workflow, utilization: 0.70},
      %{id: "amp-003", name: "AI Assistant", type: :ai_powered, utilization: 0.65}
    ]
  end

  defp get_available_amplifiers do
    [
      %{id: "amp-004", name: "Distributed Processing", type: :parallel, capacity: 0.95},
      %{id: "amp-005", name: "Smart Delegation", type: :adaptive, capacity: 0.88},
      %{id: "amp-006", name: "Predictive Analytics", type: :ai_powered, capacity: 0.92}
    ]
  end

  defp execute_balance_action(action, params) do
    try do
      case action do
        "attenuate" -> apply_attenuator(params)
        "amplify" -> apply_amplifier(params)
        "rebalance" -> automatic_rebalance(params)
        _ -> {:error, :unknown_action}
      end
    catch
      :exit, _ -> {:error, :system_offline}
    end
  end

  defp identify_root_causes(gap) do
    case gap.status do
      :attention_needed -> ["Insufficient automation", "High environmental complexity"]
      :over_controlled -> ["Excessive filtering", "Redundant controls"]
      _ -> []
    end
  end

  defp assess_impact(gap) do
    cond do
      gap.gap > 0.1 -> :high
      gap.gap > 0.05 -> :medium
      true -> :low
    end
  end

  defp calculate_priority(gap) do
    case {gap.status, assess_impact(gap)} do
      {:attention_needed, :high} -> 1
      {:attention_needed, :medium} -> 2
      {:over_controlled, _} -> 3
      _ -> 4
    end
  end

  defp apply_attenuator(params) do
    # Simulate applying an attenuator
    {:ok, %{attenuator_id: params["attenuator_id"], applied_at: DateTime.utc_now()}}
  end

  defp apply_amplifier(params) do
    # Simulate applying an amplifier
    {:ok, %{amplifier_id: params["amplifier_id"], applied_at: DateTime.utc_now()}}
  end

  defp automatic_rebalance(params) do
    # Simulate automatic rebalancing
    {:ok, %{
      actions_taken: :rand.uniform(5),
      new_balance: 0.85 + :rand.uniform() * 0.15,
      completed_at: DateTime.utc_now()
    }}
  end
end