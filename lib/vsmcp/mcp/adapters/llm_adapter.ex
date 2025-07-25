# Path: lib/vsmcp/mcp/adapters/llm_adapter.ex
defmodule Vsmcp.MCP.Adapters.LLMAdapter do
  @moduledoc """
  LLM Integration Adapter for System 4 Intelligence.
  Provides advanced language model capabilities through MCP tools
  for environmental scanning, trend analysis, and policy recommendations.
  """
  
  use GenServer
  require Logger
  
  alias Vsmcp.Systems.System4
  alias Vsmcp.MCP.{Client, CapabilityRegistry}

  # LLM Tool Configuration
  defmodule LLMTool do
    @enforce_keys [:id, :name, :type, :mcp_server, :tool_name]
    defstruct [:id, :name, :type, :mcp_server, :tool_name, :prompts, :metadata]
  end

  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  def register_llm_tool(adapter \\ __MODULE__, tool_def) do
    GenServer.call(adapter, {:register_llm_tool, tool_def})
  end

  def analyze_environment(adapter \\ __MODULE__, context, options \\ []) do
    GenServer.call(adapter, {:analyze_environment, context, options}, 60_000)
  end

  def predict_trends(adapter \\ __MODULE__, data, horizon, options \\ []) do
    GenServer.call(adapter, {:predict_trends, data, horizon, options}, 60_000)
  end

  def generate_policy_recommendation(adapter \\ __MODULE__, situation, constraints \\ []) do
    GenServer.call(adapter, {:generate_policy_recommendation, situation, constraints}, 60_000)
  end

  def analyze_variety_gap(adapter \\ __MODULE__, system_state, environment_state) do
    GenServer.call(adapter, {:analyze_variety_gap, system_state, environment_state}, 60_000)
  end

  def setup_default_llm_tools(adapter \\ __MODULE__) do
    GenServer.call(adapter, :setup_default_llm_tools)
  end

  # Server Callbacks
  
  @impl true
  def init(opts) do
    client = opts[:client] || Client
    capability_registry = opts[:capability_registry] || CapabilityRegistry
    
    # Schedule setup after init
    Process.send_after(self(), :setup_defaults, 1000)
    
    {:ok, %{
      tools: %{},
      client: client,
      capability_registry: capability_registry,
      metrics: %{
        analyses_performed: 0,
        predictions_made: 0,
        recommendations_generated: 0,
        variety_gaps_analyzed: 0
      }
    }}
  end

  @impl true
  def handle_call({:register_llm_tool, tool_def}, _from, state) do
    tool = create_llm_tool(tool_def)
    
    # Register as capability
    capability_def = %{
      name: "llm_#{tool.name}",
      type: :intelligence,
      source: %{type: :llm_adapter, adapter: __MODULE__},
      interface: %{
        handler: create_llm_handler(tool, state)
      },
      metadata: %{
        llm_type: tool.type,
        mcp_server: tool.mcp_server,
        tool: tool.tool_name
      }
    }
    
    CapabilityRegistry.register_capability(state.capability_registry, capability_def)
    
    new_tools = Map.put(state.tools, tool.id, tool)
    
    Logger.info("Registered LLM tool: #{tool.name}")
    
    {:reply, {:ok, tool.id}, %{state | tools: new_tools}}
  end

  @impl true
  def handle_call({:analyze_environment, context, options}, _from, state) do
    # Use multiple LLM tools for comprehensive analysis
    analysis_tasks = [
      Task.async(fn -> scan_with_tool("environmental_scanner", context, state) end),
      Task.async(fn -> scan_with_tool("threat_detector", context, state) end),
      Task.async(fn -> scan_with_tool("opportunity_finder", context, state) end)
    ]
    
    results = analysis_tasks
    |> Enum.map(&Task.await(&1, 30_000))
    |> Enum.reject(&match?({:error, _}, &1))
    |> Enum.map(fn {:ok, result} -> result end)
    
    # Synthesize results
    synthesis = synthesize_environmental_analysis(results, options)
    
    # Feed to System 4
    System4.scan_environment(Map.merge(context, synthesis))
    
    new_metrics = %{state.metrics | analyses_performed: state.metrics.analyses_performed + 1}
    
    {:reply, {:ok, synthesis}, %{state | metrics: new_metrics}}
  end

  @impl true
  def handle_call({:predict_trends, data, horizon, options}, _from, state) do
    # Prepare prompt for trend prediction
    prompt = build_trend_prediction_prompt(data, horizon, options)
    
    case use_llm_tool("trend_predictor", prompt, state) do
      {:ok, prediction} ->
        # Parse and structure prediction
        structured_prediction = parse_trend_prediction(prediction)
        
        # Feed to System 4
        System4.predict_future(horizon)
        
        new_metrics = %{state.metrics | predictions_made: state.metrics.predictions_made + 1}
        
        {:reply, {:ok, structured_prediction}, %{state | metrics: new_metrics}}
        
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:generate_policy_recommendation, situation, constraints}, _from, state) do
    # Build comprehensive prompt
    prompt = build_policy_recommendation_prompt(situation, constraints)
    
    case use_llm_tool("policy_advisor", prompt, state) do
      {:ok, recommendation} ->
        # Structure recommendation
        structured_rec = structure_policy_recommendation(recommendation, situation)
        
        # Create adaptation suggestion for System 4
        System4.suggest_adaptation(%{
          type: :policy_change,
          description: structured_rec.summary,
          impact: structured_rec.expected_impact
        })
        
        new_metrics = %{state.metrics | recommendations_generated: state.metrics.recommendations_generated + 1}
        
        {:reply, {:ok, structured_rec}, %{state | metrics: new_metrics}}
        
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:analyze_variety_gap, system_state, environment_state}, _from, state) do
    # Use LLM to analyze variety gap
    prompt = build_variety_gap_prompt(system_state, environment_state)
    
    case use_llm_tool("variety_analyzer", prompt, state) do
      {:ok, analysis} ->
        # Structure variety gap analysis
        gap_analysis = parse_variety_gap_analysis(analysis)
        
        # Generate recommendations for closing the gap
        recommendations = generate_variety_acquisition_recommendations(gap_analysis)
        
        new_metrics = %{state.metrics | variety_gaps_analyzed: state.metrics.variety_gaps_analyzed + 1}
        
        result = %{
          gap_analysis: gap_analysis,
          recommendations: recommendations,
          priority_actions: extract_priority_actions(gap_analysis)
        }
        
        {:reply, {:ok, result}, %{state | metrics: new_metrics}}
        
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:setup_default_llm_tools, _from, state) do
    # Register default LLM tools
    tools = [
      %{
        name: "environmental_scanner",
        type: :scanner,
        mcp_server: "openai-mcp",
        tool_name: "chat_completion",
        prompts: %{
          system: "You are an environmental scanner for a Viable System Model. Analyze the provided context and identify key signals, trends, opportunities, and threats.",
          format: "Provide analysis in JSON format with sections: signals, opportunities, threats, trends"
        }
      },
      %{
        name: "trend_predictor",
        type: :predictor,
        mcp_server: "anthropic-mcp",
        tool_name: "complete",
        prompts: %{
          system: "You are a trend prediction system. Analyze historical data and predict future trends with confidence levels.",
          format: "Structure predictions with: trend_name, direction, confidence, timeline, key_factors"
        }
      },
      %{
        name: "policy_advisor",
        type: :advisor,
        mcp_server: "openai-mcp",
        tool_name: "chat_completion",
        prompts: %{
          system: "You are a policy advisor for organizational adaptation. Generate actionable policy recommendations based on situations and constraints.",
          format: "Provide recommendations with: policy_name, objective, implementation_steps, expected_outcomes, risks"
        }
      },
      %{
        name: "variety_analyzer",
        type: :analyzer,
        mcp_server: "anthropic-mcp",
        tool_name: "complete",
        prompts: %{
          system: "You are a variety gap analyzer using Ashby's Law of Requisite Variety. Analyze the variety mismatch between system and environment.",
          format: "Analyze with: current_system_variety, required_variety, gap_magnitude, missing_capabilities, acquisition_priority"
        }
      },
      %{
        name: "threat_detector",
        type: :detector,
        mcp_server: "openai-mcp",
        tool_name: "chat_completion",
        prompts: %{
          system: "You are a threat detection system. Identify potential threats and risks from environmental signals.",
          format: "Categorize threats by: type, severity, likelihood, timeline, mitigation_options"
        }
      },
      %{
        name: "opportunity_finder",
        type: :finder,
        mcp_server: "anthropic-mcp",
        tool_name: "complete",
        prompts: %{
          system: "You are an opportunity identification system. Find potential opportunities for growth and adaptation.",
          format: "Structure opportunities with: type, potential_value, feasibility, required_resources, timeline"
        }
      }
    ]
    
    # Register each tool
    registered = Enum.map(tools, fn tool_def ->
      case handle_call({:register_llm_tool, tool_def}, nil, state) do
        {:reply, {:ok, id}, _} -> {:ok, id}
        _ -> {:error, tool_def.name}
      end
    end)
    
    success_count = Enum.count(registered, &match?({:ok, _}, &1))
    
    {:reply, {:ok, success_count}, state}
  end

  @impl true
  def handle_info(:setup_defaults, state) do
    # Setup default tools directly instead of calling self
    new_state = setup_default_tools(state)
    {:noreply, new_state}
  end

  # Private Functions
  
  defp setup_default_tools(state) do
    default_tools = [
      %{
        name: "vsm_analyzer",
        type: :analyzer,
        mcp_server: "local",
        tool_name: "vsm.variety.calculate",
        prompts: %{
          system: "Analyze variety gaps in the VSM system",
          user: "What are the current variety imbalances?"
        }
      },
      %{
        name: "future_predictor", 
        type: :predictor,
        mcp_server: "local",
        tool_name: "vsm.s4.predict",
        prompts: %{
          system: "Predict future scenarios based on current trends",
          user: "What scenarios might emerge?"
        }
      }
    ]
    
    tools = Enum.reduce(default_tools, state.tools, fn tool_def, acc ->
      tool = create_llm_tool(tool_def)
      Map.put(acc, tool.id, tool)
    end)
    
    %{state | tools: tools}
  end
  
  defp create_llm_tool(tool_def) do
    %LLMTool{
      id: generate_tool_id(tool_def),
      name: tool_def.name,
      type: tool_def.type,
      mcp_server: tool_def.mcp_server,
      tool_name: tool_def.tool_name,
      prompts: tool_def[:prompts] || %{},
      metadata: tool_def[:metadata] || %{}
    }
  end

  defp generate_tool_id(tool_def) do
    "llm_tool_#{tool_def.name}_#{:erlang.phash2(tool_def)}"
  end

  defp create_llm_handler(tool, state) do
    fn params ->
      use_llm_tool(tool.name, params[:prompt] || params[:input], state)
    end
  end

  defp scan_with_tool(tool_name, context, state) do
    prompt = build_environmental_scan_prompt(context)
    use_llm_tool(tool_name, prompt, state)
  end

  defp use_llm_tool(tool_name, prompt, state) do
    # Find the tool
    tool = state.tools
    |> Map.values()
    |> Enum.find(&(&1.name == tool_name))
    
    case tool do
      nil ->
        {:error, {:tool_not_found, tool_name}}
        
      %LLMTool{} = tool ->
        # Ensure MCP connection
        case ensure_mcp_connection(tool.mcp_server, state) do
          {:ok, server_id} ->
            # Prepare LLM call
            args = build_llm_args(tool, prompt)
            
            # Call the tool
            case Client.call_tool(state.client, server_id, tool.tool_name, args) do
              {:ok, result} ->
                {:ok, parse_llm_response(result, tool)}
                
              error ->
                error
            end
            
          error ->
            error
        end
    end
  end

  defp ensure_mcp_connection(server_name, state) do
    case Client.list_servers(state.client) do
      servers when is_list(servers) ->
        case Enum.find(servers, &(&1.name == server_name)) do
          %{id: server_id} -> {:ok, server_id}
          nil -> connect_to_llm_server(server_name, state)
        end
        
      _ ->
        connect_to_llm_server(server_name, state)
    end
  end

  defp connect_to_llm_server(server_name, state) do
    # Discover and connect to LLM MCP servers
    config = case server_name do
      "openai-mcp" ->
        %{
          name: "openai-mcp",
          transport: :stdio,
          command: "npx",
          args: ["@modelcontextprotocol/server-openai"]
        }
        
      "anthropic-mcp" ->
        %{
          name: "anthropic-mcp",
          transport: :stdio,
          command: "npx",
          args: ["@modelcontextprotocol/server-anthropic"]
        }
        
      _ ->
        nil
    end
    
    case config do
      nil ->
        {:error, {:unknown_llm_server, server_name}}
        
      config ->
        Client.connect(state.client, config)
    end
  end

  defp build_llm_args(tool, prompt) do
    base_args = %{
      "prompt" => prompt,
      "max_tokens" => 2000,
      "temperature" => 0.7
    }
    
    # Add system prompt if available
    if tool.prompts[:system] do
      Map.put(base_args, "system", tool.prompts.system)
    else
      base_args
    end
  end

  defp parse_llm_response(result, tool) do
    # Extract text from LLM response
    text = case result do
      %{"choices" => [%{"text" => text} | _]} -> text
      %{"content" => content} -> content
      %{"completion" => completion} -> completion
      _ -> inspect(result)
    end
    
    # Try to parse as JSON if format was requested
    if tool.prompts[:format] && String.contains?(tool.prompts.format, "JSON") do
      case Jason.decode(text) do
        {:ok, parsed} -> parsed
        _ -> %{"raw_response" => text}
      end
    else
      text
    end
  end

  defp build_environmental_scan_prompt(context) do
    """
    Analyze the following environmental context and identify key signals:
    
    Context:
    #{inspect(context, pretty: true)}
    
    Please identify:
    1. Key signals and their significance
    2. Potential opportunities
    3. Potential threats
    4. Emerging trends
    5. Areas requiring attention
    
    Format your response as JSON with these sections.
    """
  end

  defp build_trend_prediction_prompt(data, horizon, options) do
    """
    Based on the following data, predict trends for the next #{horizon}:
    
    Historical Data:
    #{inspect(data, pretty: true)}
    
    Analysis Parameters:
    #{inspect(options, pretty: true)}
    
    Provide predictions for:
    1. Most likely scenarios
    2. Key trend directions
    3. Confidence levels
    4. Critical factors
    5. Potential disruptions
    
    Structure your response with trend names, directions, confidence levels, and timelines.
    """
  end

  defp build_policy_recommendation_prompt(situation, constraints) do
    """
    Generate policy recommendations for the following situation:
    
    Situation:
    #{inspect(situation, pretty: true)}
    
    Constraints:
    #{inspect(constraints, pretty: true)}
    
    Provide actionable policy recommendations including:
    1. Policy name and objective
    2. Implementation steps
    3. Expected outcomes
    4. Potential risks
    5. Success metrics
    
    Ensure recommendations are practical and consider the constraints.
    """
  end

  defp build_variety_gap_prompt(system_state, environment_state) do
    """
    Analyze the variety gap using Ashby's Law of Requisite Variety:
    
    System State (Internal Variety):
    #{inspect(system_state, pretty: true)}
    
    Environment State (External Variety):
    #{inspect(environment_state, pretty: true)}
    
    Analyze:
    1. Current system variety (capabilities, responses, adaptations)
    2. Required variety to match environment
    3. Gap magnitude and critical areas
    4. Missing capabilities
    5. Priority for variety acquisition
    
    Provide structured analysis with specific capability gaps.
    """
  end

  defp synthesize_environmental_analysis(results, _options) do
    # Aggregate signals from all sources
    all_signals = results
    |> Enum.flat_map(fn result ->
      case result do
        %{"signals" => signals} -> signals
        %{signals: signals} -> signals
        _ -> []
      end
    end)
    
    all_opportunities = results
    |> Enum.flat_map(fn result ->
      case result do
        %{"opportunities" => opps} -> opps
        %{opportunities: opps} -> opps
        _ -> []
      end
    end)
    
    all_threats = results
    |> Enum.flat_map(fn result ->
      case result do
        %{"threats" => threats} -> threats
        %{threats: threats} -> threats
        _ -> []
      end
    end)
    
    %{
      signals: deduplicate_signals(all_signals),
      opportunities: prioritize_opportunities(all_opportunities),
      threats: assess_threats(all_threats),
      consensus_level: calculate_consensus(results),
      analysis_timestamp: DateTime.utc_now()
    }
  end

  defp deduplicate_signals(signals) do
    signals
    |> Enum.uniq_by(&signal_key/1)
    |> Enum.take(20) # Limit to top 20
  end

  defp signal_key(signal) do
    case signal do
      %{name: name} -> name
      %{"name" => name} -> name
      _ -> :erlang.phash2(signal)
    end
  end

  defp prioritize_opportunities(opportunities) do
    opportunities
    |> Enum.sort_by(&opportunity_score/1, :desc)
    |> Enum.take(10)
  end

  defp opportunity_score(opp) do
    value = get_in(opp, ["potential_value"]) || get_in(opp, [:potential_value]) || 0.5
    feasibility = get_in(opp, ["feasibility"]) || get_in(opp, [:feasibility]) || 0.5
    value * feasibility
  end

  defp assess_threats(threats) do
    threats
    |> Enum.sort_by(&threat_score/1, :desc)
    |> Enum.take(10)
  end

  defp threat_score(threat) do
    severity = get_in(threat, ["severity"]) || get_in(threat, [:severity]) || 0.5
    likelihood = get_in(threat, ["likelihood"]) || get_in(threat, [:likelihood]) || 0.5
    severity * likelihood
  end

  defp calculate_consensus(results) do
    if length(results) > 1 do
      # Simple consensus based on overlap
      0.7
    else
      0.5
    end
  end

  defp parse_trend_prediction(prediction) do
    case prediction do
      %{} = structured ->
        # Already structured
        Map.merge(%{
          timestamp: DateTime.utc_now(),
          confidence: 0.7
        }, structured)
        
      text when is_binary(text) ->
        # Parse text into structure
        %{
          raw_prediction: text,
          trends: extract_trends_from_text(text),
          confidence: 0.5,
          timestamp: DateTime.utc_now()
        }
    end
  end

  defp extract_trends_from_text(text) do
    # Simple extraction - would use NLP in production
    text
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ["trend", "increase", "decrease", "growth"]))
    |> Enum.map(&%{description: String.trim(&1)})
  end

  defp structure_policy_recommendation(recommendation, situation) do
    base = %{
      situation: situation,
      timestamp: DateTime.utc_now(),
      confidence: 0.8
    }
    
    case recommendation do
      %{} = structured ->
        Map.merge(base, structured)
        
      text when is_binary(text) ->
        Map.merge(base, %{
          summary: extract_summary(text),
          steps: extract_steps(text),
          expected_impact: :medium,
          raw_recommendation: text
        })
    end
  end

  defp extract_summary(text) do
    # Take first paragraph or line
    text
    |> String.split(["\n\n", "\n"], parts: 2)
    |> List.first()
    |> String.slice(0, 200)
  end

  defp extract_steps(text) do
    # Extract numbered or bulleted items
    text
    |> String.split("\n")
    |> Enum.filter(&String.match?(&1, ~r/^\d+\.|^-|^\*/))
    |> Enum.map(&String.trim/1)
  end

  defp parse_variety_gap_analysis(analysis) do
    case analysis do
      %{} = structured ->
        Map.merge(%{
          timestamp: DateTime.utc_now(),
          analysis_method: "llm_assisted"
        }, structured)
        
      text when is_binary(text) ->
        %{
          raw_analysis: text,
          gaps: extract_capability_gaps(text),
          magnitude: estimate_gap_magnitude(text),
          timestamp: DateTime.utc_now()
        }
    end
  end

  defp extract_capability_gaps(text) do
    # Extract mentioned gaps
    text
    |> String.downcase()
    |> String.split(["gap", "missing", "lack", "need"])
    |> Enum.drop(1)
    |> Enum.map(&String.slice(&1, 0, 100))
    |> Enum.map(&%{description: String.trim(&1)})
  end

  defp estimate_gap_magnitude(text) do
    cond do
      String.contains?(String.downcase(text), ["critical", "severe", "major"]) -> :high
      String.contains?(String.downcase(text), ["moderate", "medium"]) -> :medium
      true -> :low
    end
  end

  defp generate_variety_acquisition_recommendations(gap_analysis) do
    gaps = gap_analysis[:gaps] || []
    
    Enum.map(gaps, fn gap ->
      %{
        capability_gap: gap,
        recommendation: "Acquire capability to handle: #{gap[:description]}",
        priority: assign_priority(gap),
        implementation: suggest_implementation(gap)
      }
    end)
  end

  defp assign_priority(gap) do
    # Simple priority assignment
    case gap[:severity] do
      :high -> :critical
      :medium -> :important
      _ -> :normal
    end
  end

  defp suggest_implementation(gap) do
    %{
      approach: "Tool acquisition through MCP",
      timeline: "2-4 weeks",
      resources: "MCP server integration"
    }
  end

  defp extract_priority_actions(gap_analysis) do
    gap_analysis
    |> Map.get(:gaps, [])
    |> Enum.sort_by(&(&1[:priority] || 0), :desc)
    |> Enum.take(3)
    |> Enum.map(&%{action: "Close gap: #{&1[:description]}", priority: :high})
  end
end