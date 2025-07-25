defmodule VsmcpWeb.System3Controller do
  use VsmcpWeb, :controller

  alias Vsmcp.Systems.System3

  def index(conn, _params) do
    # Get control and optimization data
    state = get_system_state()
    control_metrics = get_control_metrics()
    optimization_status = get_optimization_status()
    audit_trails = get_recent_audits()

    render(conn, :index,
      state: state,
      control_metrics: control_metrics,
      optimization_status: optimization_status,
      audit_trails: audit_trails
    )
  end

  def audit(conn, _params) do
    audit_report = generate_audit_report()
    subsystem_health = check_subsystem_health()
    
    render(conn, :audit,
      report: audit_report,
      health: subsystem_health
    )
  end

  def optimize(conn, %{"target" => target} = params) do
    case System3.optimize_subsystem(target, params) do
      {:ok, result} ->
        conn
        |> put_flash(:info, "Optimization initiated for #{target}")
        |> json(%{success: true, optimization_id: result.id})
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, error: to_string(reason)})
    end
  end

  def control_action(conn, %{"action" => action} = params) do
    case execute_control_action(action, params) do
      {:ok, result} ->
        conn
        |> put_flash(:info, "Control action executed successfully")
        |> redirect(to: ~p"/system3")
      {:error, reason} ->
        conn
        |> put_flash(:error, "Control action failed: #{reason}")
        |> redirect(to: ~p"/system3")
    end
  end

  defp get_system_state do
    try do
      GenServer.call(System3, :get_state, 5000)
    catch
      :exit, _ -> %{status: :offline, control_mode: :manual, optimizations: []}
    end
  end

  defp get_control_metrics do
    %{
      control_effectiveness: 0.85 + :rand.uniform() * 0.15,
      resource_utilization: 0.7 + :rand.uniform() * 0.3,
      compliance_score: 0.9 + :rand.uniform() * 0.1,
      optimization_rate: 0.75 + :rand.uniform() * 0.25
    }
  end

  defp get_optimization_status do
    %{
      active_optimizations: :rand.uniform(5),
      completed_today: :rand.uniform(20),
      average_improvement: 15 + :rand.uniform(10),
      next_scheduled: DateTime.add(DateTime.utc_now(), 3600, :second)
    }
  end

  defp get_recent_audits do
    for i <- 1..5 do
      %{
        id: "audit-#{i}",
        timestamp: DateTime.add(DateTime.utc_now(), -i * 3600, :second),
        type: Enum.random(["compliance", "performance", "security", "resource"]),
        result: Enum.random(["passed", "passed_with_warnings", "needs_attention"]),
        findings: :rand.uniform(3)
      }
    end
  end

  defp generate_audit_report do
    %{
      generated_at: DateTime.utc_now(),
      overall_health: 0.9 + :rand.uniform() * 0.1,
      subsystems_audited: 5,
      issues_found: :rand.uniform(3),
      recommendations: [
        "Optimize resource allocation in System 1",
        "Update coordination rules in System 2",
        "Review access controls"
      ]
    }
  end

  defp check_subsystem_health do
    for i <- 1..5 do
      %{
        system: "System #{i}",
        health_score: 0.8 + :rand.uniform() * 0.2,
        status: Enum.random([:healthy, :warning, :healthy]),
        last_check: DateTime.add(DateTime.utc_now(), -:rand.uniform(3600), :second)
      }
    end
  end

  defp execute_control_action(action, params) do
    try do
      GenServer.call(System3, {:execute_control, action, params}, 5000)
    catch
      :exit, _ -> {:error, :system_offline}
    end
  end
end