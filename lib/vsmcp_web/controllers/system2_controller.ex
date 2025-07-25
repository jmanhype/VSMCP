defmodule VsmcpWeb.System2Controller do
  use VsmcpWeb, :controller

  alias Vsmcp.Systems.System2

  def index(conn, _params) do
    # Get coordination state and anti-oscillation data
    state = get_system_state()
    coordination_rules = get_coordination_rules()
    oscillation_data = get_oscillation_metrics()

    render(conn, :index,
      state: state,
      coordination_rules: coordination_rules,
      oscillation_data: oscillation_data
    )
  end

  def rules(conn, _params) do
    rules = get_all_coordination_rules()
    render(conn, :rules, rules: rules)
  end

  def create_rule(conn, %{"rule" => rule_params}) do
    case System2.add_coordination_rule(rule_params) do
      {:ok, rule} ->
        conn
        |> put_flash(:info, "Coordination rule created successfully")
        |> redirect(to: ~p"/system2/rules")
      {:error, changeset} ->
        render(conn, :new_rule, changeset: changeset)
    end
  end

  def oscillations(conn, _params) do
    oscillation_history = get_oscillation_history()
    current_dampening = get_dampening_status()
    
    render(conn, :oscillations,
      history: oscillation_history,
      dampening: current_dampening
    )
  end

  defp get_system_state do
    try do
      GenServer.call(System2, :get_state, 5000)
    catch
      :exit, _ -> %{status: :offline, rules: [], dampening: :inactive}
    end
  end

  defp get_coordination_rules do
    try do
      GenServer.call(System2, :get_coordination_rules, 5000)
    catch
      :exit, _ -> []
    end
  end

  defp get_oscillation_metrics do
    %{
      detected: :rand.uniform(10),
      dampened: :rand.uniform(8),
      frequency: :rand.uniform() * 0.5,
      amplitude: :rand.uniform() * 0.3
    }
  end

  defp get_all_coordination_rules do
    try do
      GenServer.call(System2, :list_all_rules, 5000)
    catch
      :exit, _ -> []
    end
  end

  defp get_oscillation_history do
    # Generate sample oscillation history
    for i <- 1..20 do
      %{
        timestamp: DateTime.add(DateTime.utc_now(), -i * 60, :second),
        amplitude: :rand.uniform() * 0.5,
        frequency: :rand.uniform() * 0.3,
        dampened: :rand.uniform() > 0.3
      }
    end
  end

  defp get_dampening_status do
    %{
      active: true,
      effectiveness: 0.85 + :rand.uniform() * 0.15,
      rules_applied: :rand.uniform(5)
    }
  end
end