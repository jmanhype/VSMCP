defmodule VsmcpWeb.System4Controller do
  use VsmcpWeb, :controller

  alias Vsmcp.Systems.System4

  def index(conn, _params) do
    # Get intelligence and adaptation data
    state = get_system_state()
    intelligence_metrics = get_intelligence_metrics()
    environmental_scan = get_environmental_data()
    predictions = get_predictions()

    render(conn, :index,
      state: state,
      intelligence_metrics: intelligence_metrics,
      environmental_scan: environmental_scan,
      predictions: predictions
    )
  end

  def predictions(conn, _params) do
    short_term = get_short_term_predictions()
    long_term = get_long_term_predictions()
    scenarios = get_scenario_analysis()
    
    render(conn, :predictions,
      short_term: short_term,
      long_term: long_term,
      scenarios: scenarios
    )
  end

  def environmental_scan(conn, %{"scope" => scope} = params) do
    scan_results = perform_environmental_scan(scope, params)
    
    json(conn, %{
      success: true,
      scan_id: scan_results.id,
      findings: scan_results.findings,
      recommendations: scan_results.recommendations
    })
  end

  def adapt(conn, %{"adaptation" => adaptation_params}) do
    case System4.propose_adaptation(adaptation_params) do
      {:ok, proposal} ->
        conn
        |> put_flash(:info, "Adaptation proposal created: #{proposal.id}")
        |> redirect(to: ~p"/system4")
      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to create adaptation: #{reason}")
        |> redirect(to: ~p"/system4")
    end
  end

  defp get_system_state do
    try do
      GenServer.call(System4, :get_state, 5000)
    catch
      :exit, _ -> %{status: :offline, scanning: false, adaptations: []}
    end
  end

  defp get_intelligence_metrics do
    %{
      pattern_recognition: 0.85 + :rand.uniform() * 0.15,
      prediction_accuracy: 0.75 + :rand.uniform() * 0.20,
      environmental_awareness: 0.9 + :rand.uniform() * 0.1,
      adaptation_readiness: 0.8 + :rand.uniform() * 0.2
    }
  end

  defp get_environmental_data do
    %{
      last_scan: DateTime.add(DateTime.utc_now(), -3600, :second),
      threats_detected: :rand.uniform(3),
      opportunities_identified: :rand.uniform(5),
      market_volatility: :rand.uniform() * 0.5,
      competitive_landscape: Enum.random(["stable", "shifting", "turbulent"])
    }
  end

  defp get_predictions do
    for i <- 1..5 do
      %{
        id: "pred-#{i}",
        category: Enum.random(["demand", "resource", "market", "technology", "regulatory"]),
        timeframe: Enum.random(["1 week", "1 month", "3 months", "1 year"]),
        confidence: 0.7 + :rand.uniform() * 0.3,
        impact: Enum.random(["low", "medium", "high", "critical"])
      }
    end
  end

  defp get_short_term_predictions do
    for i <- 1..3 do
      %{
        metric: Enum.random(["throughput", "demand", "cost", "efficiency"]),
        current_value: 50 + :rand.uniform(50),
        predicted_value: 50 + :rand.uniform(50),
        timeframe: "#{i} week(s)",
        confidence: 0.8 + :rand.uniform() * 0.2
      }
    end
  end

  defp get_long_term_predictions do
    for i <- 1..3 do
      %{
        trend: Enum.random(["market_growth", "technology_shift", "regulatory_change"]),
        probability: 0.6 + :rand.uniform() * 0.4,
        timeframe: "#{i * 3} months",
        impact_assessment: Enum.random(["positive", "neutral", "negative", "transformative"])
      }
    end
  end

  defp get_scenario_analysis do
    [
      %{
        name: "Best Case",
        probability: 0.25,
        key_assumptions: ["Market growth continues", "No major disruptions"],
        projected_outcome: "30% growth"
      },
      %{
        name: "Base Case",
        probability: 0.50,
        key_assumptions: ["Moderate market conditions", "Normal competition"],
        projected_outcome: "15% growth"
      },
      %{
        name: "Worst Case",
        probability: 0.25,
        key_assumptions: ["Market downturn", "Increased competition"],
        projected_outcome: "5% decline"
      }
    ]
  end

  defp perform_environmental_scan(scope, params) do
    %{
      id: "scan-#{:rand.uniform(1000)}",
      findings: %{
        threats: :rand.uniform(5),
        opportunities: :rand.uniform(8),
        neutral_factors: :rand.uniform(10)
      },
      recommendations: [
        "Monitor emerging technology X",
        "Prepare for regulatory change Y",
        "Explore partnership opportunity Z"
      ]
    }
  end
end