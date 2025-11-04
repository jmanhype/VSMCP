# Path: lib/vsmcp.ex
defmodule Vsmcp do
  @moduledoc """
  VSMCP - Viable System Model with Model Context Protocol
  
  This is the main entry point for the VSMCP system, implementing
  Stafford Beer's Viable System Model with dynamic capability
  acquisition through the Model Context Protocol.
  
  ## Overview
  
  The system implements all 5 VSM systems:
  - System 1: Operations (Operational units)
  - System 2: Coordination (Anti-oscillation)
  - System 3: Control (Resource bargaining)
  - System 4: Intelligence (Future planning)
  - System 5: Policy (Identity and ethos)
  
  ## Key Features
  
  - Real-time variety calculation using Ashby's Law
  - Dynamic capability acquisition through MCP
  - Consciousness interface for meta-cognition
  - Full autonomy with self-improvement
  """

  alias Vsmcp.Core.VarietyCalculator
  alias Vsmcp.Systems.{System1, System2, System3, System4, System5}
  alias Vsmcp.Consciousness.Interface

  @doc """
  Get the current system status including all subsystems.

  Returns a map containing the status of all 5 VSM systems,
  variety calculations, and consciousness interface state.
  """
  @spec status() :: map()
  def status do
    %{
      system_1: System1.status(),
      system_2: System2.status(),
      system_3: System3.status(),
      system_4: System4.status(),
      system_5: System5.status(),
      variety: VarietyCalculator.current_state(),
      consciousness: Interface.status()
    }
  end

  @doc """
  Analyze variety gaps between operational and environmental complexity.

  Returns analysis of the gap between the system's operational variety
  and the environmental variety it must manage.
  """
  @spec analyze_variety() :: {:ok, list(map())} | {:error, term()}
  def analyze_variety do
    VarietyCalculator.analyze_gaps()
  end

  @doc """
  Make a strategic decision using the full VSM hierarchy.

  Coordinates all 5 systems to make a strategic decision based on
  the provided context. The decision flows through System 5 (policy),
  System 4 (intelligence), System 3 (control), System 2 (coordination),
  and System 1 (execution).

  ## Parameters

  - `context`: A map containing decision context including constraints,
    objectives, environment, and other relevant factors.

  ## Returns

  The result from System 1 execution of the coordinated plan.
  """
  @spec make_decision(map()) :: {:ok, term()} | {:error, term()}
  def make_decision(context) do
    # System 5 sets policy
    policy = System5.get_policy(context)
    
    # System 4 scans environment
    intelligence = System4.scan_environment(context)
    
    # System 3 optimizes resources
    optimization = System3.optimize(context, policy, intelligence)
    
    # System 2 coordinates execution
    coordination = System2.coordinate(optimization)
    
    # System 1 executes operations
    System1.execute(coordination)
  end

  @doc """
  Query the consciousness interface for self-awareness.

  Engages the meta-cognitive reflection system to analyze the
  system's own state, limitations, and opportunities.

  ## Parameters

  - `query`: A string describing what to reflect upon

  ## Examples

      iex> Vsmcp.reflect("What are my current limitations?")
      {:ok, "Current limitations: ..."}
  """
  @spec reflect(String.t()) :: {:ok, String.t()} | {:error, term()}
  def reflect(query) do
    Interface.reflect(query)
  end
end
