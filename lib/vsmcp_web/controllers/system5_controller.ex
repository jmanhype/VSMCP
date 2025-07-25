defmodule VsmcpWeb.System5Controller do
  use VsmcpWeb, :controller

  alias Vsmcp.Systems.System5

  def index(conn, _params) do
    # Get policy and identity data
    state = get_system_state()
    policies = get_active_policies()
    identity_metrics = get_identity_metrics()
    governance_status = get_governance_status()

    render(conn, :index,
      state: state,
      policies: policies,
      identity_metrics: identity_metrics,
      governance_status: governance_status
    )
  end

  def policies(conn, _params) do
    all_policies = get_all_policies()
    policy_hierarchy = get_policy_hierarchy()
    
    render(conn, :policies,
      policies: all_policies,
      hierarchy: policy_hierarchy
    )
  end

  def create_policy(conn, %{"policy" => policy_params}) do
    case System5.create_policy(policy_params) do
      {:ok, policy} ->
        conn
        |> put_flash(:info, "Policy created successfully")
        |> redirect(to: ~p"/system5/policies")
      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to create policy: #{reason}")
        |> redirect(to: ~p"/system5/policies")
    end
  end

  def ethos(conn, _params) do
    organizational_ethos = get_organizational_ethos()
    value_alignment = calculate_value_alignment()
    
    render(conn, :ethos,
      ethos: organizational_ethos,
      alignment: value_alignment
    )
  end

  def governance(conn, _params) do
    governance_structure = get_governance_structure()
    decision_rights = get_decision_rights()
    accountability_matrix = get_accountability_matrix()
    
    render(conn, :governance,
      structure: governance_structure,
      rights: decision_rights,
      accountability: accountability_matrix
    )
  end

  defp get_system_state do
    try do
      GenServer.call(System5, :get_state, 5000)
    catch
      :exit, _ -> %{status: :offline, policies: [], ethos: %{}}
    end
  end

  defp get_active_policies do
    [
      %{
        id: "pol-001",
        name: "Security First",
        category: "operational",
        priority: "critical",
        status: "active",
        last_reviewed: DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second)
      },
      %{
        id: "pol-002",
        name: "Customer Focus",
        category: "strategic",
        priority: "high",
        status: "active",
        last_reviewed: DateTime.add(DateTime.utc_now(), -15 * 24 * 3600, :second)
      },
      %{
        id: "pol-003",
        name: "Continuous Improvement",
        category: "cultural",
        priority: "high",
        status: "active",
        last_reviewed: DateTime.add(DateTime.utc_now(), -7 * 24 * 3600, :second)
      }
    ]
  end

  defp get_identity_metrics do
    %{
      coherence_score: 0.9 + :rand.uniform() * 0.1,
      value_alignment: 0.85 + :rand.uniform() * 0.15,
      purpose_clarity: 0.95,
      ethos_strength: 0.88 + :rand.uniform() * 0.12
    }
  end

  defp get_governance_status do
    %{
      decision_latency: "#{:rand.uniform(3) + 1}h",
      policy_compliance: 0.92 + :rand.uniform() * 0.08,
      accountability_score: 0.88 + :rand.uniform() * 0.12,
      transparency_index: 0.9 + :rand.uniform() * 0.1
    }
  end

  defp get_all_policies do
    get_active_policies() ++ [
      %{
        id: "pol-004",
        name: "Data Privacy",
        category: "regulatory",
        priority: "high",
        status: "draft",
        last_reviewed: DateTime.utc_now()
      },
      %{
        id: "pol-005",
        name: "Sustainability",
        category: "strategic",
        priority: "medium",
        status: "under_review",
        last_reviewed: DateTime.add(DateTime.utc_now(), -45 * 24 * 3600, :second)
      }
    ]
  end

  defp get_policy_hierarchy do
    %{
      core_values: ["Security", "Innovation", "Reliability", "Transparency"],
      strategic_policies: ["Customer Focus", "Continuous Improvement", "Sustainability"],
      operational_policies: ["Security First", "Data Privacy", "Quality Standards"],
      tactical_policies: ["Incident Response", "Change Management", "Resource Allocation"]
    }
  end

  defp get_organizational_ethos do
    %{
      mission: "To create viable, self-regulating systems that enhance human capability",
      vision: "A world where organizations operate with perfect variety balance",
      values: [
        %{name: "Autonomy", description: "Empower subsystems to self-regulate"},
        %{name: "Recursion", description: "Apply viable principles at every level"},
        %{name: "Adaptation", description: "Continuously evolve with the environment"},
        %{name: "Purpose", description: "Maintain clear identity and direction"}
      ],
      principles: [
        "Requisite variety must be maintained",
        "Information should flow without distortion",
        "Local autonomy within global coherence",
        "Continuous environmental scanning"
      ]
    }
  end

  defp calculate_value_alignment do
    for subsystem <- ["System1", "System2", "System3", "System4"] do
      %{
        subsystem: subsystem,
        alignment_score: 0.8 + :rand.uniform() * 0.2,
        key_gaps: Enum.random([[], ["Communication", "Resources"], ["Training"]])
      }
    end
  end

  defp get_governance_structure do
    %{
      model: "Viable System Model",
      decision_levels: [
        %{level: 5, name: "Policy", scope: "Identity and ethos"},
        %{level: 4, name: "Intelligence", scope: "Future and environment"},
        %{level: 3, name: "Control", scope: "Internal regulation"},
        %{level: 2, name: "Coordination", scope: "Anti-oscillation"},
        %{level: 1, name: "Operations", scope: "Primary activities"}
      ],
      reporting_lines: "Recursive and bi-directional"
    }
  end

  defp get_decision_rights do
    %{
      system5: ["Policy creation", "Identity definition", "Ultimate authority"],
      system4: ["Environmental scanning", "Future planning", "Adaptation proposals"],
      system3: ["Resource allocation", "Performance standards", "Audit"],
      system2: ["Coordination rules", "Information flow", "Conflict resolution"],
      system1: ["Operational decisions", "Implementation", "Local optimization"]
    }
  end

  defp get_accountability_matrix do
    [
      %{role: "System 5", accountable_for: "Overall viability", reports_to: "Stakeholders"},
      %{role: "System 4", accountable_for: "Environmental adaptation", reports_to: "System 5"},
      %{role: "System 3", accountable_for: "Internal stability", reports_to: "System 5"},
      %{role: "System 2", accountable_for: "Coordination", reports_to: "System 3"},
      %{role: "System 1", accountable_for: "Operations", reports_to: "System 3"}
    ]
  end
end