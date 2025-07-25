# Path: test/vsmcp/mcp/llm_integration_test.exs
defmodule Vsmcp.MCP.LLMIntegrationTest do
  use ExUnit.Case, async: false
  
  alias Vsmcp.MCP.Adapters.LLMAdapter
  alias Vsmcp.MCP.Tools.System4LLMTools
  alias Vsmcp.MCP.Feedback.LLMFeedbackLoop
  alias Vsmcp.MCP.Prompts.VSMPromptEngineering
  alias Vsmcp.MCP.{ToolRegistry, CapabilityRegistry}
  
  setup do
    # Start necessary applications
    Application.ensure_all_started(:vsmcp)
    
    # Clean registries
    :ets.delete_all_objects(:mcp_tools)
    :ets.delete_all_objects(:mcp_capabilities)
    
    # Register test tools
    System4LLMTools.register_all()
    
    :ok
  end
  
  describe "LLM Adapter" do
    test "registers default LLM tools" do
      {:ok, count} = LLMAdapter.setup_default_llm_tools()
      assert count > 0
    end
    
    test "analyzes environment with LLM" do
      context = %{
        market: "volatile",
        technology: "rapidly changing",
        regulation: "increasing"
      }
      
      # This would normally call actual LLM
      # For testing, we verify the structure
      assert {:ok, _analysis} = LLMAdapter.analyze_environment(context)
    end
    
    test "predicts trends" do
      data = %{metrics: [1, 2, 3, 4, 5]}
      horizon = "6months"
      
      assert {:ok, _predictions} = LLMAdapter.predict_trends(data, horizon)
    end
    
    test "generates policy recommendations" do
      situation = %{challenge: "market disruption"}
      constraints = ["budget limited", "time critical"]
      
      assert {:ok, _recommendation} = LLMAdapter.generate_policy_recommendation(situation, constraints)
    end
    
    test "analyzes variety gap" do
      system_state = %{capabilities: ["A", "B", "C"]}
      environment_state = %{demands: ["A", "B", "C", "D", "E"]}
      
      assert {:ok, result} = LLMAdapter.analyze_variety_gap(system_state, environment_state)
      assert Map.has_key?(result, :gap_analysis)
      assert Map.has_key?(result, :recommendations)
    end
  end
  
  describe "System4 LLM Tools" do
    test "environmental scanner tool is registered" do
      assert {:ok, tool} = ToolRegistry.get_tool("vsm.s4.llm.scan_environment")
      assert tool.info().name == "vsm.s4.llm.scan_environment"
    end
    
    test "trend predictor tool is registered" do
      assert {:ok, tool} = ToolRegistry.get_tool("vsm.s4.llm.predict_trends")
      assert tool.info().name == "vsm.s4.llm.predict_trends"
    end
    
    test "policy advisor tool is registered" do
      assert {:ok, tool} = ToolRegistry.get_tool("vsm.s4.llm.generate_policy")
      assert tool.info().name == "vsm.s4.llm.generate_policy"
    end
    
    test "variety gap analyzer tool is registered" do
      assert {:ok, tool} = ToolRegistry.get_tool("vsm.s4.llm.analyze_variety_gap")
      assert tool.info().name == "vsm.s4.llm.analyze_variety_gap"
    end
    
    test "environmental scanner executes with valid args" do
      {:ok, tool} = ToolRegistry.get_tool("vsm.s4.llm.scan_environment")
      
      result = tool.execute(%{
        "domain" => "technology",
        "context" => %{signals: []},
        "depth" => "standard"
      })
      
      assert result.type == :success
      assert Map.has_key?(result.content, "domain")
      assert Map.has_key?(result.content, "signals")
    end
  end
  
  describe "LLM Feedback Loop" do
    test "processes LLM insights" do
      insight = %{
        threats: [
          %{description: "Test threat", severity: :high, impact: :high}
        ],
        opportunities: [
          %{description: "Test opportunity", potential_value: 0.8}
        ]
      }
      
      assert {:ok, feedbacks} = LLMFeedbackLoop.process_llm_insight(insight)
      assert is_list(feedbacks)
      assert length(feedbacks) > 0
    end
    
    test "creates control adjustments" do
      analysis = %{
        risks: [%{area: "security", mitigation: "enhance monitoring"}],
        improvements: [%{process: "data flow", change: "optimize"}]
      }
      
      assert {:ok, adjustment} = LLMFeedbackLoop.create_control_adjustment(analysis, :system3)
      assert adjustment.target == :system3
      assert is_list(adjustment.adjustments)
    end
    
    test "filters feedback history" do
      # Process some insights first
      insight = %{threats: [%{description: "Test", severity: :high, impact: :high}]}
      {:ok, _} = LLMFeedbackLoop.process_llm_insight(insight)
      
      # Get history
      history = LLMFeedbackLoop.get_feedback_history(limit: 10)
      assert is_list(history)
    end
    
    test "enables/disables auto feedback" do
      assert :ok = LLMFeedbackLoop.enable_auto_feedback(false)
      assert :ok = LLMFeedbackLoop.enable_auto_feedback(true)
    end
  end
  
  describe "VSM Prompt Engineering" do
    test "generates prompts for different systems" do
      context = %{data: "test data"}
      
      prompt = VSMPromptEngineering.generate_prompt(context, system: :system4)
      assert is_binary(prompt)
      assert String.contains?(prompt, "environmental")
    end
    
    test "generates diagnostic questions" do
      questions = VSMPromptEngineering.generate_diagnostic_questions(:diagnostic)
      assert is_list(questions)
      assert length(questions) > 0
    end
    
    test "generates variety engineering prompt" do
      capabilities = ["cap1", "cap2"]
      demands = ["demand1", "demand2", "demand3"]
      
      prompt = VSMPromptEngineering.generate_variety_prompt(capabilities, demands)
      assert is_binary(prompt)
      assert String.contains?(prompt, "Ashby's Law")
    end
    
    test "validates prompts" do
      good_prompt = "Analyze the system variety and control mechanisms in this organization"
      bad_prompt = "Hi"
      
      assert {:ok, _} = VSMPromptEngineering.validate_prompt(good_prompt)
      assert {:error, issues} = VSMPromptEngineering.validate_prompt(bad_prompt)
      assert is_list(issues)
    end
    
    test "provides system roles" do
      role = VSMPromptEngineering.get_system_role(:system4)
      assert is_binary(role)
      assert String.contains?(role, "environmental")
    end
    
    test "generates recursive analysis prompt" do
      subsystem_data = %{name: "Manufacturing", level: 1}
      prompt = VSMPromptEngineering.generate_recursive_prompt(subsystem_data, 2)
      assert is_binary(prompt)
      assert String.contains?(prompt, "recursive")
    end
  end
  
  describe "Integration Tests" do
    test "LLM tools integrate with capability registry" do
      # Register a test LLM tool
      tool_def = %{
        name: "test_llm_tool",
        type: :test,
        mcp_server: "test-mcp",
        tool_name: "test",
        prompts: %{system: "Test system prompt"}
      }
      
      {:ok, tool_id} = LLMAdapter.register_llm_tool(tool_def)
      assert is_binary(tool_id)
      
      # Check capability was registered
      capabilities = CapabilityRegistry.list_capabilities()
      assert Enum.any?(capabilities, fn cap ->
        cap.name == "llm_test_llm_tool"
      end)
    end
    
    test "feedback loop integrates with System 3" do
      # This tests the integration pattern
      # In real deployment, would verify System 3 receives adjustments
      
      insight = %{
        variety_gap: %{
          magnitude: :high,
          missing_capabilities: ["real-time processing", "ML inference"]
        }
      }
      
      assert {:ok, feedbacks} = LLMFeedbackLoop.process_llm_insight(insight)
      
      # Verify critical feedback was generated
      critical_feedback = Enum.find(feedbacks, & &1.priority == :critical)
      assert critical_feedback != nil
      assert critical_feedback.type == :variety_adjustment
    end
    
    test "prompt engineering generates valid MCP tool inputs" do
      # Generate a prompt for environmental scanning
      context = %{market: "volatile", competition: "increasing"}
      prompt = VSMPromptEngineering.generate_prompt(context, 
        system: :system4,
        template: :environmental_scan,
        format: :structured
      )
      
      # Verify prompt includes JSON format instructions
      assert String.contains?(prompt, "JSON")
      assert String.contains?(prompt, "threats")
      assert String.contains?(prompt, "opportunities")
    end
  end
  
  describe "Error Handling" do
    test "handles missing LLM servers gracefully" do
      # Try to use a non-existent tool
      tool_def = %{
        name: "nonexistent",
        type: :test,
        mcp_server: "nonexistent-mcp",
        tool_name: "test"
      }
      
      {:ok, _} = LLMAdapter.register_llm_tool(tool_def)
      
      # Should handle connection failure gracefully
      result = LLMAdapter.analyze_environment(%{test: true})
      assert match?({:ok, _} or {:error, _}, result)
    end
    
    test "handles invalid prompt templates" do
      context = %{data: "test"}
      prompt = VSMPromptEngineering.generate_prompt(context,
        template: :nonexistent_template
      )
      
      # Should return empty or default prompt
      assert is_binary(prompt)
    end
  end
end