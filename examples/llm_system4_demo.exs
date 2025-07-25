#!/usr/bin/env elixir
# Path: examples/llm_system4_demo.exs

# Demo: LLM-powered System 4 Intelligence

Mix.install([
  {:vsmcp, path: "./"},
  {:jason, "~> 1.4"}
])

defmodule LLMSystem4Demo do
  @moduledoc """
  Demonstrates LLM integration as System 4 intelligence in VSMCP.
  Shows environmental scanning, trend prediction, and policy recommendations.
  """
  
  alias Vsmcp.MCP.{Client, ToolRegistry}
  alias Vsmcp.MCP.Adapters.LLMAdapter
  alias Vsmcp.MCP.Tools.System4LLMTools
  alias Vsmcp.MCP.Prompts.VSMPromptEngineering
  alias Vsmcp.MCP.Feedback.LLMFeedbackLoop
  
  def run do
    IO.puts """
    ╔══════════════════════════════════════════════════════════════╗
    ║          LLM-Powered System 4 Intelligence Demo              ║
    ╚══════════════════════════════════════════════════════════════╝
    """
    
    # Start the VSMCP application
    {:ok, _} = Application.ensure_all_started(:vsmcp)
    
    # Give systems time to initialize
    Process.sleep(2000)
    
    # Register System 4 LLM tools
    IO.puts "\n🔧 Registering System 4 LLM tools..."
    System4LLMTools.register_all()
    
    # Setup default LLM tools
    IO.puts "\n🤖 Setting up LLM intelligence sources..."
    {:ok, tool_count} = LLMAdapter.setup_default_llm_tools()
    IO.puts "   ✅ Registered #{tool_count} LLM tools"
    
    # Demo 1: Environmental Scanning
    demo_environmental_scanning()
    
    # Demo 2: Trend Prediction
    demo_trend_prediction()
    
    # Demo 3: Policy Recommendation
    demo_policy_recommendation()
    
    # Demo 4: Variety Gap Analysis
    demo_variety_gap_analysis()
    
    # Demo 5: Feedback Loop
    demo_feedback_loop()
    
    # Demo 6: Prompt Engineering
    demo_prompt_engineering()
    
    IO.puts "\n✅ LLM System 4 Demo Complete!"
  end
  
  defp demo_environmental_scanning do
    IO.puts "\n📡 Demo 1: Environmental Scanning with LLM"
    IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Simulate environmental context
    context = %{
      market_conditions: %{
        competition: "increasing",
        customer_demands: ["AI integration", "real-time analytics", "automation"],
        price_pressure: "high"
      },
      technology_trends: %{
        emerging: ["quantum computing", "edge AI", "autonomous systems"],
        declining: ["traditional databases", "manual processes"]
      },
      regulatory_changes: %{
        new_requirements: ["data privacy", "AI ethics", "carbon reporting"],
        compliance_deadlines: "6-12 months"
      }
    }
    
    # Call LLM environmental scanner
    case call_tool("vsm.s4.llm.scan_environment", %{
      "domain" => "all",
      "context" => context,
      "depth" => "deep"
    }) do
      {:ok, result} ->
        IO.puts "\n🔍 Environmental Scan Results:"
        IO.puts "   Threats detected: #{length(result["threats"])}"
        IO.puts "   Opportunities found: #{length(result["opportunities"])}"
        IO.puts "   Confidence level: #{Float.round(result["confidence"], 2)}"
        
        # Show top threats
        if length(result["threats"]) > 0 do
          IO.puts "\n   ⚠️  Top Threats:"
          result["threats"]
          |> Enum.take(3)
          |> Enum.each(fn threat ->
            IO.puts "      - #{threat["description"]} (Impact: #{threat["impact"]})"
          end)
        end
        
        # Show top opportunities
        if length(result["opportunities"]) > 0 do
          IO.puts "\n   💡 Top Opportunities:"
          result["opportunities"]
          |> Enum.take(3)
          |> Enum.each(fn opp ->
            IO.puts "      - #{opp["description"]} (Value: #{opp["value"]})"
          end)
        end
        
      {:error, reason} ->
        IO.puts "   ❌ Scan failed: #{inspect(reason)}"
    end
  end
  
  defp demo_trend_prediction do
    IO.puts "\n📈 Demo 2: Trend Prediction with LLM"
    IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Call trend predictor
    case call_tool("vsm.s4.llm.predict_trends", %{
      "data_source" => "market_analytics",
      "horizon" => "6months",
      "focus" => ["AI adoption", "automation", "sustainability"],
      "confidence_threshold" => 0.7
    }) do
      {:ok, result} ->
        IO.puts "\n📊 Trend Predictions:"
        IO.puts "   Horizon: #{result["horizon"]}"
        IO.puts "   Total predictions: #{result["total_predictions"]}"
        IO.puts "   Average confidence: #{Float.round(result["average_confidence"], 2)}"
        
        if length(result["key_trends"]) > 0 do
          IO.puts "\n   🔮 Key Trends:"
          result["key_trends"]
          |> Enum.with_index(1)
          |> Enum.each(fn {trend, idx} ->
            IO.puts "      #{idx}. #{trend}"
          end)
        end
        
      {:error, reason} ->
        IO.puts "   ❌ Prediction failed: #{inspect(reason)}"
    end
  end
  
  defp demo_policy_recommendation do
    IO.puts "\n📋 Demo 3: Policy Recommendation with LLM"
    IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    situation = %{
      "challenge" => "Rapid AI adoption by competitors",
      "current_state" => "Limited AI capabilities",
      "resources" => "Medium budget, skilled team",
      "timeline" => "6 months to catch up"
    }
    
    # Generate policy recommendation
    case call_tool("vsm.s4.llm.generate_policy", %{
      "situation" => situation,
      "objectives" => ["Achieve AI parity", "Maintain operational stability", "Build future capability"],
      "constraints" => ["Budget limitations", "No disruption to current operations", "Regulatory compliance"],
      "urgency" => "high"
    }) do
      {:ok, result} ->
        IO.puts "\n📝 Policy Recommendation:"
        IO.puts "   Policy: #{result["policy"]}"
        IO.puts "   Timeline: #{result["timeline"]}"
        
        if length(result["implementation_steps"]) > 0 do
          IO.puts "\n   📌 Implementation Steps:"
          result["implementation_steps"]
          |> Enum.take(5)
          |> Enum.with_index(1)
          |> Enum.each(fn {step, idx} ->
            IO.puts "      #{idx}. #{step}"
          end)
        end
        
        if length(result["risks"]) > 0 do
          IO.puts "\n   ⚠️  Risks:"
          result["risks"]
          |> Enum.each(fn risk ->
            IO.puts "      - #{risk}"
          end)
        end
        
      {:error, reason} ->
        IO.puts "   ❌ Policy generation failed: #{inspect(reason)}"
    end
  end
  
  defp demo_variety_gap_analysis do
    IO.puts "\n🔄 Demo 4: Variety Gap Analysis with LLM"
    IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Current system capabilities
    system_capabilities = [
      "Basic data processing",
      "Rule-based automation",
      "Structured reporting",
      "Scheduled batch operations",
      "Manual decision making"
    ]
    
    # Environmental demands
    environmental_demands = [
      "Real-time data processing",
      "AI-driven insights",
      "Predictive analytics",
      "Continuous adaptation",
      "Autonomous decision making",
      "Multi-modal data handling",
      "Edge computing",
      "Quantum-ready algorithms"
    ]
    
    # Analyze variety gap
    case call_tool("vsm.s4.llm.analyze_variety_gap", %{
      "system_capabilities" => system_capabilities,
      "environmental_demands" => environmental_demands,
      "performance_data" => %{
        "response_time" => "slow",
        "adaptation_rate" => "low",
        "error_rate" => "medium"
      },
      "analysis_depth" => "comprehensive"
    }) do
      {:ok, result} ->
        IO.puts "\n🎯 Variety Gap Analysis:"
        
        gap = result["variety_gap"]
        if gap do
          IO.puts "   System Variety: #{gap["system"]}"
          IO.puts "   Environment Variety: #{gap["environment"]}"
          IO.puts "   Gap: #{gap["gap"]}"
        end
        
        if length(result["missing_capabilities"]) > 0 do
          IO.puts "\n   🔍 Missing Capabilities:"
          result["missing_capabilities"]
          |> Enum.take(5)
          |> Enum.each(fn cap ->
            IO.puts "      - #{cap["capability"]} (via #{cap["acquisition_method"]})"
          end)
        end
        
        if result["acquisition_plan"] do
          IO.puts "\n   📅 Acquisition Plan:"
          result["acquisition_plan"]["phases"]
          |> Enum.each(fn phase ->
            IO.puts "      Phase #{phase["phase"]}: #{phase["name"]} (#{phase["duration"]})"
          end)
        end
        
      {:error, reason} ->
        IO.puts "   ❌ Gap analysis failed: #{inspect(reason)}"
    end
  end
  
  defp demo_feedback_loop do
    IO.puts "\n🔄 Demo 5: LLM Feedback Loop to System 3"
    IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Simulate an LLM insight
    insight = %{
      threats: [
        %{
          description: "Competitor launching AI-powered product",
          severity: :high,
          impact: :high,
          timeline: "2 months"
        }
      ],
      opportunities: [
        %{
          description: "Partnership opportunity with AI startup",
          potential_value: 0.8,
          feasibility: 0.7
        }
      ],
      variety_gap: %{
        magnitude: :high,
        missing_capabilities: ["ML operations", "real-time inference"]
      }
    }
    
    # Process through feedback loop
    case LLMFeedbackLoop.process_llm_insight(insight) do
      {:ok, feedbacks} ->
        IO.puts "\n📤 Feedback sent to System 3:"
        IO.puts "   Total feedback items: #{length(feedbacks)}"
        
        feedbacks
        |> Enum.group_by(& &1.type)
        |> Enum.each(fn {type, items} ->
          IO.puts "   - #{type}: #{length(items)} items"
        end)
        
        # Show feedback history
        history = LLMFeedbackLoop.get_feedback_history(limit: 5)
        if length(history) > 0 do
          IO.puts "\n   📊 Recent Feedback History:"
          history
          |> Enum.take(3)
          |> Enum.each(fn feedback ->
            IO.puts "      • #{feedback.type} (#{feedback.priority}) - #{feedback.status}"
          end)
        end
        
      {:error, reason} ->
        IO.puts "   ❌ Feedback processing failed: #{inspect(reason)}"
    end
  end
  
  defp demo_prompt_engineering do
    IO.puts "\n🎯 Demo 6: VSM-Specific Prompt Engineering"
    IO.puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Generate diagnostic questions
    IO.puts "\n📋 Diagnostic Questions for VSM Analysis:"
    questions = VSMPromptEngineering.generate_diagnostic_questions(:diagnostic)
    questions
    |> Enum.take(5)
    |> Enum.with_index(1)
    |> Enum.each(fn {q, idx} ->
      IO.puts "   #{idx}. #{q}"
    end)
    
    # Generate a variety engineering prompt
    IO.puts "\n🔧 Variety Engineering Prompt:"
    variety_prompt = VSMPromptEngineering.generate_variety_prompt(
      ["Process A", "Process B", "Tool X"],
      ["Demand 1", "Demand 2", "Demand 3", "Demand 4", "Demand 5"],
      focus: "automation capabilities"
    )
    
    # Show first 200 characters of prompt
    IO.puts "   #{String.slice(variety_prompt, 0, 200)}..."
    
    # Validate prompt
    case VSMPromptEngineering.validate_prompt(variety_prompt) do
      {:ok, msg} -> IO.puts "   ✅ #{msg}"
      {:error, issues} -> IO.puts "   ❌ Issues: #{Enum.join(issues, ", ")}"
    end
    
    # Show available system roles
    IO.puts "\n🎭 Available System Roles:"
    [:system1, :system2, :system3, :system4, :system5]
    |> Enum.each(fn system ->
      role = VSMPromptEngineering.get_system_role(system)
      preview = String.slice(role, 0, 80)
      IO.puts "   #{system}: #{preview}..."
    end)
  end
  
  defp call_tool(tool_name, args) do
    case ToolRegistry.get_tool(tool_name) do
      {:ok, tool} ->
        result = tool.execute(args)
        case result do
          %{type: :success, content: content} -> {:ok, content}
          %{type: :error, error: error} -> {:error, error}
          _ -> {:error, :unknown_result}
        end
        
      {:error, _} ->
        # For demo purposes, return mock data if tool not found
        mock_result(tool_name)
    end
  end
  
  defp mock_result("vsm.s4.llm.scan_environment") do
    {:ok, %{
      "threats" => [
        %{"description" => "New competitor with AI capabilities", "impact" => "high"},
        %{"description" => "Regulatory changes in 6 months", "impact" => "medium"}
      ],
      "opportunities" => [
        %{"description" => "Growing market for AI solutions", "value" => "high"},
        %{"description" => "Partnership opportunities", "value" => "medium"}
      ],
      "confidence" => 0.85
    }}
  end
  
  defp mock_result("vsm.s4.llm.predict_trends") do
    {:ok, %{
      "horizon" => "6months",
      "total_predictions" => 5,
      "average_confidence" => 0.75,
      "key_trends" => [
        "AI adoption will accelerate 50% in next 6 months",
        "Automation will become mandatory for competitiveness",
        "Real-time analytics will be baseline expectation"
      ]
    }}
  end
  
  defp mock_result("vsm.s4.llm.generate_policy") do
    {:ok, %{
      "policy" => "Accelerated AI Integration Strategy",
      "timeline" => "1-4 weeks",
      "implementation_steps" => [
        "Form AI task force",
        "Assess current capabilities",
        "Identify quick wins",
        "Partner with AI vendors",
        "Launch pilot projects"
      ],
      "risks" => [
        "Integration complexity",
        "Team skill gaps",
        "Budget overruns"
      ]
    }}
  end
  
  defp mock_result("vsm.s4.llm.analyze_variety_gap") do
    {:ok, %{
      "variety_gap" => %{
        "system" => 5,
        "environment" => 8,
        "gap" => 3
      },
      "missing_capabilities" => [
        %{"capability" => "Real-time ML inference", "acquisition_method" => "MCP tool integration"},
        %{"capability" => "Autonomous decision making", "acquisition_method" => "Capability development"},
        %{"capability" => "Multi-modal data processing", "acquisition_method" => "Training or hiring"}
      ],
      "acquisition_plan" => %{
        "phases" => [
          %{"phase" => 1, "name" => "Immediate acquisitions", "duration" => "2 weeks"},
          %{"phase" => 2, "name" => "Short-term improvements", "duration" => "1-2 months"},
          %{"phase" => 3, "name" => "Strategic enhancements", "duration" => "3-6 months"}
        ]
      }
    }}
  end
  
  defp mock_result(_), do: {:error, :not_implemented}
end

# Run the demo
LLMSystem4Demo.run()