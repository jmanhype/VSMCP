defmodule VsmcpWeb.PageController do
  use VsmcpWeb, :controller

  def home(conn, _params) do
    # Gather system status data
    system_status = %{
      system1: get_system_status(Vsmcp.Systems.System1),
      system2: get_system_status(Vsmcp.Systems.System2),
      system3: get_system_status(Vsmcp.Systems.System3),
      system4: get_system_status(Vsmcp.Systems.System4),
      system5: get_system_status(Vsmcp.Systems.System5),
      amqp: get_amqp_status(),
      mcp: get_mcp_status(),
      variety: calculate_variety_metrics()
    }

    render(conn, :home, system_status: system_status)
  end

  defp get_system_status(system_module) do
    try do
      case GenServer.call(system_module, :get_state, 5000) do
        state when is_map(state) ->
          %{
            status: :online,
            metrics: Map.get(state, :metrics, %{}),
            last_update: Map.get(state, :last_update, DateTime.utc_now())
          }
        _ ->
          %{status: :online, metrics: %{}, last_update: DateTime.utc_now()}
      end
    catch
      :exit, {:noproc, _} ->
        %{status: :offline, metrics: %{}, last_update: nil}
      :exit, {:timeout, _} ->
        %{status: :timeout, metrics: %{}, last_update: nil}
      _, _ ->
        %{status: :error, metrics: %{}, last_update: nil}
    end
  end

  defp get_amqp_status do
    try do
      case Process.whereis(Vsmcp.AMQP.ConnectionPool) do
        nil -> 
          %{status: :offline, channels: 0, messages: 0}
        pid when is_pid(pid) ->
          %{
            status: :online,
            channels: :ets.info(:amqp_channels, :size) || 0,
            messages: get_message_count()
          }
      end
    catch
      _, _ -> %{status: :error, channels: 0, messages: 0}
    end
  end

  defp get_mcp_status do
    try do
      case Process.whereis(Vsmcp.MCP.ServerManager) do
        nil -> 
          %{status: :offline, servers: 0, tools: 0}
        pid when is_pid(pid) ->
          servers = GenServer.call(pid, :list_servers, 5000)
          %{
            status: :online,
            servers: length(servers),
            tools: count_total_tools(servers)
          }
      end
    catch
      _, _ -> %{status: :error, servers: 0, tools: 0}
    end
  end

  defp calculate_variety_metrics do
    try do
      case Process.whereis(Vsmcp.Core.VarietyCalculator) do
        nil -> 
          %{score: 0.0, trend: :stable, requisite: 0.0}
        pid when is_pid(pid) ->
          GenServer.call(pid, :get_metrics, 5000)
      end
    catch
      _, _ -> %{score: 0.0, trend: :stable, requisite: 0.0}
    end
  end

  defp get_message_count do
    # This would typically query AMQP for actual message counts
    # For now, return a simulated value
    :rand.uniform(1000)
  end

  defp count_total_tools(servers) do
    Enum.reduce(servers, 0, fn {_name, server_info}, acc ->
      acc + length(Map.get(server_info, :tools, []))
    end)
  end
end