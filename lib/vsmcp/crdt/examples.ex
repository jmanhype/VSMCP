defmodule Vsmcp.CRDT.Examples do
  @moduledoc """
  Example usage patterns for CRDT ContextStore in VSM systems.
  Shows how different VSM subsystems can leverage CRDTs for distributed state.
  """

  alias Vsmcp.CRDT.ContextStore

  @doc """
  Example: System 1 operational units using counters for metrics.
  """
  def system1_metrics_example do
    # Each operational unit tracks its own metrics
    :ok = ContextStore.create(:unit1_processed, :g_counter)
    :ok = ContextStore.create(:unit1_errors, :pn_counter)
    
    # Process items
    {:ok, _} = ContextStore.increment(:unit1_processed, 10)
    
    # Track errors (can be corrected)
    {:ok, _} = ContextStore.increment(:unit1_errors, 2)
    {:ok, _} = ContextStore.decrement(:unit1_errors, 1)  # Error was false positive
    
    # Get current metrics
    {:ok, processed} = ContextStore.get(:unit1_processed)
    {:ok, errors} = ContextStore.get(:unit1_errors)
    
    %{processed: processed, errors: errors}
  end

  @doc """
  Example: System 2 coordination using sets for active operations.
  """
  def system2_coordination_example do
    # Track active operations across units
    :ok = ContextStore.create(:active_operations, :or_set)
    
    # Units register their operations
    {:ok, _} = ContextStore.add(:active_operations, {:unit1, :process_order, "order_123"})
    {:ok, _} = ContextStore.add(:active_operations, {:unit2, :quality_check, "batch_456"})
    
    # Check current operations
    {:ok, operations} = ContextStore.get(:active_operations)
    
    # Complete an operation
    {:ok, _} = ContextStore.remove(:active_operations, {:unit1, :process_order, "order_123"})
    
    operations
  end

  @doc """
  Example: System 3 using registers for current state/policy.
  """
  def system3_policy_example do
    # Store current operational policy
    :ok = ContextStore.create(:current_policy, :lww_register)
    
    policy = %{
      resource_allocation: %{
        unit1: 0.4,
        unit2: 0.3,
        unit3: 0.3
      },
      priority_mode: :balanced,
      timestamp: System.system_time(:millisecond)
    }
    
    {:ok, _} = ContextStore.set(:current_policy, policy)
    
    # System 3 updates policy based on monitoring
    updated_policy = %{
      resource_allocation: %{
        unit1: 0.5,  # Increased allocation
        unit2: 0.3,
        unit3: 0.2   # Decreased allocation
      },
      priority_mode: :urgent,
      timestamp: System.system_time(:millisecond)
    }
    
    {:ok, _} = ContextStore.set(:current_policy, updated_policy)
    {:ok, current} = ContextStore.get(:current_policy)
    
    current
  end

  @doc """
  Example: System 4 strategic planning with environment scanning.
  """
  def system4_environment_example do
    # Track environmental factors
    :ok = ContextStore.create(:opportunities, :or_set)
    :ok = ContextStore.create(:threats, :or_set)
    :ok = ContextStore.create(:market_trends, :lww_register)
    
    # Add identified opportunities
    {:ok, _} = ContextStore.add(:opportunities, %{
      id: "opp_001",
      type: :market_expansion,
      region: :asia_pacific,
      potential: :high
    })
    
    # Track threats
    {:ok, _} = ContextStore.add(:threats, %{
      id: "threat_001",
      type: :competitor,
      severity: :medium,
      timeline: :q2_2024
    })
    
    # Update market trends
    {:ok, _} = ContextStore.set(:market_trends, %{
      growth_rate: 0.15,
      demand_forecast: :increasing,
      technology_shift: :ai_automation
    })
    
    # Retrieve for strategic planning
    {:ok, opps} = ContextStore.get(:opportunities)
    {:ok, threats} = ContextStore.get(:threats)
    {:ok, trends} = ContextStore.get(:market_trends)
    
    %{
      opportunities: opps,
      threats: threats,
      market_trends: trends
    }
  end

  @doc """
  Example: System 5 identity and purpose tracking.
  """
  def system5_identity_example do
    # Core identity elements
    :ok = ContextStore.create(:core_values, :or_set)
    :ok = ContextStore.create(:mission_statement, :lww_register)
    :ok = ContextStore.create(:strategic_objectives, :or_set)
    
    # Define core values
    {:ok, _} = ContextStore.add(:core_values, :sustainability)
    {:ok, _} = ContextStore.add(:core_values, :innovation)
    {:ok, _} = ContextStore.add(:core_values, :customer_focus)
    
    # Set mission
    {:ok, _} = ContextStore.set(:mission_statement, 
      "To create sustainable value through innovative solutions that exceed customer expectations")
    
    # Add strategic objectives
    {:ok, _} = ContextStore.add(:strategic_objectives, %{
      id: "obj_001",
      description: "Achieve carbon neutrality by 2030",
      timeline: "2030-12-31",
      priority: :high
    })
    
    {:ok, values} = ContextStore.get(:core_values)
    {:ok, mission} = ContextStore.get(:mission_statement)
    {:ok, objectives} = ContextStore.get(:strategic_objectives)
    
    %{
      core_values: values,
      mission: mission,
      strategic_objectives: objectives
    }
  end

  @doc """
  Example: Algedonic signal tracking using counters.
  """
  def algedonic_signals_example do
    # Track pain/pleasure signals
    :ok = ContextStore.create(:pain_signals, :g_counter)
    :ok = ContextStore.create(:pleasure_signals, :g_counter)
    
    # System experiences pain (problems, failures)
    {:ok, _} = ContextStore.increment(:pain_signals, 5)
    
    # System experiences pleasure (successes, achievements)
    {:ok, _} = ContextStore.increment(:pleasure_signals, 8)
    
    # Calculate algedonic balance
    {:ok, pain} = ContextStore.get(:pain_signals)
    {:ok, pleasure} = ContextStore.get(:pleasure_signals)
    
    balance = pleasure - pain
    
    %{
      pain: pain,
      pleasure: pleasure,
      balance: balance,
      state: cond do
        balance > 5 -> :thriving
        balance > 0 -> :healthy
        balance > -5 -> :stressed
        true -> :critical
      end
    }
  end

  @doc """
  Example: Distributed consensus tracking for multi-node VSM.
  """
  def distributed_consensus_example do
    # Track consensus decisions across nodes
    :ok = ContextStore.create(:consensus_proposals, :or_set)
    :ok = ContextStore.create(:consensus_votes, :pn_counter)
    
    # Node proposes a change
    proposal = %{
      id: "prop_001",
      type: :resource_reallocation,
      proposer: node(),
      timestamp: System.system_time(:millisecond),
      details: %{
        from: :unit2,
        to: :unit1,
        amount: 0.1
      }
    }
    
    {:ok, _} = ContextStore.add(:consensus_proposals, proposal)
    
    # Nodes vote (positive or negative)
    {:ok, _} = ContextStore.increment(:consensus_votes, 3)  # 3 yes votes
    {:ok, _} = ContextStore.decrement(:consensus_votes, 1)  # 1 no vote
    
    # Check if consensus reached
    {:ok, net_votes} = ContextStore.get(:consensus_votes)
    {:ok, proposals} = ContextStore.get(:consensus_proposals)
    
    %{
      proposals: proposals,
      net_votes: net_votes,
      consensus: net_votes > 0
    }
  end
end