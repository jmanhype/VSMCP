# Path: lib/vsmcp/mcp/prompts/vsm_prompt_engineering.ex
defmodule Vsmcp.MCP.Prompts.VSMPromptEngineering do
  @moduledoc """
  VSM-specific prompt engineering for LLM interactions.
  Provides optimized prompts for various VSM operations and analyses.
  """
  
  # System role prompts for different VSM contexts
  @system_roles %{
    system1: """
    You are an operational intelligence system for a Viable System Model's System 1.
    Your role is to analyze and optimize operational activities, identify inefficiencies,
    and suggest improvements while maintaining operational stability.
    Focus on immediate, practical solutions that can be implemented quickly.
    """,
    
    system2: """
    You are a coordination specialist for a Viable System Model's System 2.
    Your role is to identify and resolve conflicts between operational units,
    optimize information flow, and ensure smooth coordination without oscillation.
    Focus on communication patterns, scheduling, and resource sharing.
    """,
    
    system3: """
    You are a control and audit system for a Viable System Model's System 3.
    Your role is to monitor performance, ensure compliance, optimize resource allocation,
    and maintain operational cohesion. Focus on control mechanisms, performance metrics,
    and synergy between units.
    """,
    
    system4: """
    You are an environmental intelligence system for a Viable System Model's System 4.
    Your role is to scan the environment for threats and opportunities, predict future trends,
    and recommend strategic adaptations. Focus on external changes, emerging patterns,
    and long-term viability.
    """,
    
    system5: """
    You are a policy and identity system for a Viable System Model's System 5.
    Your role is to maintain organizational identity, set policy, balance present and future,
    and ensure overall system viability. Focus on values, purpose, and strategic direction.
    """,
    
    variety_engineer: """
    You are a variety engineering specialist applying Ashby's Law of Requisite Variety.
    Your role is to analyze variety mismatches between system and environment,
    identify capability gaps, and recommend variety amplification or attenuation strategies.
    Focus on matching internal variety to external complexity.
    """
  }
  
  # Prompt templates for common VSM analyses
  @analysis_templates %{
    operational_efficiency: """
    Analyze the following operational data for System 1 units:
    {data}
    
    Identify:
    1. Efficiency bottlenecks and their root causes
    2. Resource utilization patterns
    3. Performance variations between units
    4. Quick wins for improvement
    5. Systemic issues requiring coordination
    
    Provide specific, actionable recommendations with implementation timelines.
    """,
    
    coordination_analysis: """
    Examine the following coordination challenges in System 2:
    {data}
    
    Analyze:
    1. Information flow blockages
    2. Scheduling conflicts and their patterns
    3. Resource contention points
    4. Communication gaps between units
    5. Oscillation or instability patterns
    
    Suggest coordination mechanisms to resolve these issues without adding bureaucracy.
    """,
    
    control_optimization: """
    Review the following control data from System 3:
    {data}
    
    Evaluate:
    1. Control loop effectiveness
    2. Audit findings and patterns
    3. Resource allocation efficiency
    4. Synergy opportunities between units
    5. Performance metric adequacy
    
    Recommend control adjustments that enhance performance without stifling autonomy.
    """,
    
    environmental_scan: """
    Analyze the following environmental signals for System 4:
    {data}
    
    Identify:
    1. Emerging threats with probability and impact assessment
    2. New opportunities with feasibility analysis
    3. Trend trajectories and inflection points
    4. Competitive landscape changes
    5. Regulatory or technological disruptions
    
    Provide strategic recommendations with confidence levels and time horizons.
    """,
    
    policy_formulation: """
    Based on the following organizational context for System 5:
    {data}
    
    Develop:
    1. Policy recommendations aligned with organizational identity
    2. Balance between current operations and future adaptation
    3. Value-based decision criteria
    4. Strategic priorities for resource allocation
    5. Identity-preserving transformation strategies
    
    Ensure policies maintain viability while enabling necessary change.
    """,
    
    variety_gap_analysis: """
    Compare the following system and environmental states:
    System State: {system_state}
    Environmental State: {environment_state}
    
    Using Ashby's Law of Requisite Variety, analyze:
    1. Current variety ratio (system:environment)
    2. Critical variety gaps by domain
    3. Amplification opportunities (increasing system variety)
    4. Attenuation opportunities (reducing environmental variety)
    5. Priority capabilities for acquisition
    
    Provide a variety engineering plan with specific mechanisms.
    """,
    
    recursive_viability: """
    Analyze the following subsystem for recursive viability:
    {data}
    
    Assess:
    1. Presence and effectiveness of all 5 systems
    2. Recursive depth and clarity
    3. Autonomy vs integration balance
    4. Information channel adequacy
    5. Viability at each recursive level
    
    Identify structural improvements to enhance recursive viability.
    """,
    
    algedonic_signal: """
    Interpret the following algedonic (pain/pleasure) signal:
    {data}
    
    Determine:
    1. Signal urgency and required response time
    2. Source system and propagation path
    3. Underlying systemic issue
    4. Immediate mitigation steps
    5. Long-term resolution strategy
    
    Prioritize system survival while addressing root causes.
    """
  }
  
  # Question templates for interactive VSM analysis
  @question_templates %{
    diagnostic: [
      "What specific operational challenges is System 1 facing?",
      "How effective are the current coordination mechanisms in System 2?",
      "What control metrics does System 3 use and are they adequate?",
      "What environmental changes has System 4 detected recently?",
      "How well-defined is the organizational identity in System 5?"
    ],
    
    improvement: [
      "What would increase operational variety in System 1?",
      "How can we reduce coordination overhead in System 2?",
      "What additional control mechanisms would help System 3?",
      "What intelligence sources should System 4 monitor?",
      "How can System 5 better balance stability and change?"
    ],
    
    integration: [
      "How well do the 5 systems communicate with each other?",
      "Are there missing or weak channels between systems?",
      "Is the recursive structure clear and functional?",
      "How quickly do algedonic signals reach System 5?",
      "Is there appropriate autonomy at each recursive level?"
    ]
  }
  
  # Generate a complete prompt for VSM analysis
  def generate_prompt(context, options \\ []) do
    system = options[:system] || :system4
    template = options[:template] || :environmental_scan
    include_role = options[:include_role] || true
    format = options[:format] || :structured
    
    prompt = ""
    
    # Add system role if requested
    if include_role do
      prompt = prompt <> get_system_role(system) <> "\n\n"
    end
    
    # Add main analysis template
    prompt = prompt <> get_analysis_template(template, context)
    
    # Add format instructions
    if format == :structured do
      prompt = prompt <> "\n\n" <> get_format_instructions(template)
    end
    
    prompt
  end
  
  # Generate a diagnostic questionnaire
  def generate_diagnostic_questions(focus \\ :all) do
    case focus do
      :all ->
        @question_templates
        |> Map.values()
        |> List.flatten()
        
      category when is_atom(category) ->
        Map.get(@question_templates, category, [])
        
      systems when is_list(systems) ->
        systems
        |> Enum.flat_map(&get_system_questions/1)
    end
  end
  
  # Generate a variety engineering prompt
  def generate_variety_prompt(system_capabilities, environmental_demands, options \\ []) do
    context = %{
      system_state: format_capabilities(system_capabilities),
      environment_state: format_demands(environmental_demands)
    }
    
    base_prompt = get_analysis_template(:variety_gap_analysis, context)
    
    # Add specific focus if provided
    if options[:focus] do
      base_prompt <> "\n\nPay special attention to: #{options[:focus]}"
    else
      base_prompt
    end
  end
  
  # Generate a recursive analysis prompt
  def generate_recursive_prompt(subsystem_data, level \\ 1) do
    context = Map.merge(subsystem_data, %{
      recursive_level: level,
      parent_system: subsystem_data[:parent] || "root"
    })
    
    get_analysis_template(:recursive_viability, context)
  end
  
  # Get role prompt for a specific system
  def get_system_role(system) do
    Map.get(@system_roles, system, @system_roles[:system4])
  end
  
  # Get analysis template with context interpolation
  def get_analysis_template(template, context) do
    template_string = Map.get(@analysis_templates, template, "")
    
    # Interpolate context values
    Enum.reduce(context, template_string, fn {key, value}, acc ->
      placeholder = "{#{key}}"
      String.replace(acc, placeholder, format_value(value))
    end)
  end
  
  # Format context values for prompt inclusion
  defp format_value(value) when is_map(value) or is_list(value) do
    Jason.encode!(value, pretty: true)
  end
  
  defp format_value(value), do: to_string(value)
  
  # Format capabilities for variety analysis
  defp format_capabilities(capabilities) when is_list(capabilities) do
    capabilities
    |> Enum.with_index(1)
    |> Enum.map(fn {cap, idx} -> "#{idx}. #{cap}" end)
    |> Enum.join("\n")
  end
  
  defp format_capabilities(capabilities), do: format_value(capabilities)
  
  # Format environmental demands
  defp format_demands(demands) when is_list(demands) do
    demands
    |> Enum.with_index(1)
    |> Enum.map(fn {demand, idx} -> "#{idx}. #{demand}" end)
    |> Enum.join("\n")
  end
  
  defp format_demands(demands), do: format_value(demands)
  
  # Get format instructions based on template type
  defp get_format_instructions(template) do
    case template do
      :operational_efficiency ->
        """
        Format your response as JSON with the following structure:
        {
          "bottlenecks": [{"issue": "...", "cause": "...", "impact": "..."}],
          "quick_wins": [{"action": "...", "benefit": "...", "timeline": "..."}],
          "systemic_issues": [{"issue": "...", "systems_affected": [...]}],
          "recommendations": [{"priority": "...", "action": "...", "expected_outcome": "..."}]
        }
        """
        
      :environmental_scan ->
        """
        Format your response as JSON with the following structure:
        {
          "threats": [{"description": "...", "probability": 0.0-1.0, "impact": "low|medium|high", "timeline": "..."}],
          "opportunities": [{"description": "...", "feasibility": 0.0-1.0, "value": "low|medium|high", "requirements": [...]}],
          "trends": [{"name": "...", "direction": "...", "confidence": 0.0-1.0, "implications": [...]}],
          "recommendations": [{"action": "...", "rationale": "...", "priority": "...", "timeframe": "..."}]
        }
        """
        
      :variety_gap_analysis ->
        """
        Format your response as JSON with the following structure:
        {
          "variety_ratio": {"system": X, "environment": Y, "gap": Y-X},
          "critical_gaps": [{"domain": "...", "missing_variety": "...", "impact": "..."}],
          "amplification_options": [{"mechanism": "...", "variety_gain": "...", "cost": "..."}],
          "attenuation_options": [{"mechanism": "...", "variety_reduction": "...", "feasibility": "..."}],
          "acquisition_priorities": [{"capability": "...", "priority": 1-5, "implementation": "..."}]
        }
        """
        
      _ ->
        "Please structure your response with clear sections and specific, actionable recommendations."
    end
  end
  
  # Generate questions for specific systems
  defp get_system_questions(system) do
    case system do
      :system1 ->
        [
          "What are the main operational processes?",
          "How is performance measured?",
          "What resources are available?",
          "What constraints exist?"
        ]
        
      :system2 ->
        [
          "What coordination mechanisms are in place?",
          "Where do conflicts typically arise?",
          "How is information shared?",
          "What causes delays or oscillations?"
        ]
        
      :system3 ->
        [
          "What control metrics are monitored?",
          "How often are audits performed?",
          "How are resources allocated?",
          "What synergies exist between units?"
        ]
        
      :system4 ->
        [
          "What environmental factors are monitored?",
          "How are trends identified?",
          "What predictive models are used?",
          "How far ahead is planning done?"
        ]
        
      :system5 ->
        [
          "What is the organizational purpose?",
          "What are the core values?",
          "How are policies developed?",
          "How is balance maintained?"
        ]
        
      _ ->
        []
    end
  end
  
  # Generate a meta-prompt for prompt optimization
  def generate_meta_prompt(original_prompt, feedback) do
    """
    You are a prompt engineering specialist for VSM (Viable System Model) applications.
    
    Original prompt:
    #{original_prompt}
    
    Feedback received:
    #{feedback}
    
    Please improve the prompt to:
    1. Better align with VSM principles and terminology
    2. Elicit more specific and actionable responses
    3. Reduce ambiguity and increase precision
    4. Include appropriate context without overwhelming detail
    5. Guide toward systemic rather than symptomatic solutions
    
    Provide the improved prompt and explain the key changes made.
    """
  end
  
  # Validate prompt quality
  def validate_prompt(prompt) do
    issues = []
    
    # Check length
    if String.length(prompt) < 50 do
      issues = ["Prompt too short" | issues]
    end
    
    if String.length(prompt) > 2000 do
      issues = ["Prompt too long" | issues]
    end
    
    # Check for VSM concepts
    vsm_terms = ["system", "variety", "control", "coordination", "environment", "viability"]
    if not Enum.any?(vsm_terms, &String.contains?(String.downcase(prompt), &1)) do
      issues = ["Missing VSM terminology" | issues]
    end
    
    # Check for clear instructions
    if not String.contains?(prompt, "?") and not String.contains?(prompt, ":") do
      issues = ["No clear question or instruction" | issues]
    end
    
    case issues do
      [] -> {:ok, "Valid VSM prompt"}
      _ -> {:error, issues}
    end
  end
end