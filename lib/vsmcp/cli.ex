defmodule Vsmcp.CLI do
  @moduledoc """
  Command Line Interface for VSMCP control and management.
  Provides programmatic access to all CLI commands.
  """

  alias Vsmcp.{
    VSM.VarietyAnalyzer,
    VSM.CapabilityRegistry,
    MCP.ServerRegistry,
    MCP.CapabilityManager,
    MCP.ConnectionTester,
    MCP.Discovery,
    MCP.Installer,
    Telemetry.Metrics
  }

  require Logger

  @doc """
  Get the system status
  """
  def status do
    %{
      node: Node.self(),
      applications: started_applications(),
      uptime: uptime(),
      memory: memory_usage(),
      processes: process_info(),
      cluster: cluster_status(),
      health: health_status()
    }
    |> format_status()
  end

  @doc """
  Perform health check
  """
  def health_check do
    checks = [
      check_applications(),
      check_database(),
      check_amqp(),
      check_memory(),
      check_processes(),
      check_message_queues()
    ]

    failed = Enum.filter(checks, fn {_name, status, _details} -> status != :ok end)

    if Enum.empty?(failed) do
      {:ok, "All health checks passed"}
    else
      {:error, "Health checks failed", failed}
    end
  end

  @doc """
  Generate variety gap report
  """
  def variety_report(format \\ :text) do
    # Analyze system variety
    system_variety = VarietyAnalyzer.analyze_system_variety()
    env_variety = VarietyAnalyzer.analyze_environment_variety()
    gaps = VarietyAnalyzer.identify_variety_gaps(system_variety, env_variety)
    recommendations = VarietyAnalyzer.recommend_capabilities(gaps)
    mcp_capabilities = CapabilityRegistry.list_capabilities()

    report = %{
      timestamp: DateTime.utc_now(),
      system_variety: system_variety,
      environment_variety: env_variety,
      variety_gaps: gaps,
      recommendations: recommendations,
      current_capabilities: mcp_capabilities,
      analysis: %{
        gap_count: length(gaps),
        coverage_percentage: VarietyAnalyzer.calculate_coverage(system_variety, env_variety),
        critical_gaps: Enum.filter(gaps, & &1.severity == :critical)
      }
    }

    format_variety_report(report, format)
  end

  @doc """
  List MCP capabilities
  """
  def list_mcp_capabilities do
    servers = ServerRegistry.list_servers()
    
    capabilities = Enum.map(servers, fn server ->
      caps = CapabilityManager.get_capabilities(server.id)
      
      %{
        server: server,
        capabilities: caps,
        total: length(caps)
      }
    end)

    total_capabilities = capabilities
    |> Enum.map(& &1.total)
    |> Enum.sum()

    %{
      servers: capabilities,
      total_capabilities: total_capabilities
    }
  end

  @doc """
  Install MCP server
  """
  def install_mcp_server(server_name) do
    case Installer.install_server(server_name) do
      {:ok, server} ->
        {:ok, "Successfully installed #{server.name} v#{server.version}"}
        
      {:error, reason} ->
        {:error, "Failed to install #{server_name}: #{inspect(reason)}"}
    end
  end

  @doc """
  Remove MCP server
  """
  def remove_mcp_server(server_name) do
    case Installer.remove_server(server_name) do
      :ok ->
        {:ok, "Successfully removed #{server_name}"}
        
      {:error, reason} ->
        {:error, "Failed to remove #{server_name}: #{inspect(reason)}"}
    end
  end

  @doc """
  Discover available MCP servers
  """
  def discover_mcp_servers do
    servers = Discovery.discover_servers()
    
    %{
      available: length(servers),
      servers: Enum.map(servers, fn server ->
        %{
          name: server.name,
          description: server.description,
          capabilities: server.capabilities,
          installed: server.installed
        }
      end)
    }
  end

  @doc """
  Test MCP connections
  """
  def test_mcp_connections(server_name \\ nil) do
    if server_name do
      test_single_mcp_connection(server_name)
    else
      test_all_mcp_connections()
    end
  end

  @doc """
  Get system metrics
  """
  def get_metrics do
    %{
      system: Metrics.get_system_metrics(),
      application: Metrics.get_application_metrics(),
      mcp: Metrics.get_mcp_metrics(),
      vsm: Metrics.get_vsm_metrics()
    }
  end

  # Private functions

  defp started_applications do
    Application.started_applications()
    |> Enum.map(fn {app, _desc, _vsn} -> app end)
  end

  defp uptime do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    format_duration(uptime_ms)
  end

  defp memory_usage do
    memory = :erlang.memory()
    
    %{
      total_mb: memory[:total] / 1_048_576,
      processes_mb: memory[:processes] / 1_048_576,
      system_mb: memory[:system] / 1_048_576,
      atom_mb: memory[:atom] / 1_048_576,
      ets_mb: memory[:ets] / 1_048_576,
      binary_mb: memory[:binary] / 1_048_576
    }
  end

  defp process_info do
    processes = :erlang.processes()
    
    %{
      total: length(processes),
      schedulers: :erlang.system_info(:schedulers_online),
      run_queue: :erlang.statistics(:run_queue)
    }
  end

  defp cluster_status do
    nodes = Node.list()
    
    %{
      connected_nodes: length(nodes),
      nodes: nodes,
      cookie: Node.get_cookie() != nil
    }
  end

  defp health_status do
    case health_check() do
      {:ok, _} -> :healthy
      {:error, _, _} -> :unhealthy
    end
  end

  defp check_applications do
    required = [:vsmcp, :amqp, :phoenix_pubsub, :telemetry]
    started = started_applications()
    missing = required -- started
    
    if Enum.empty?(missing) do
      {"applications", :ok, "All required applications running"}
    else
      {"applications", :error, "Missing applications: #{inspect(missing)}"}
    end
  end

  defp check_database do
    # This is a placeholder - implement based on your actual database setup
    {"database", :ok, "Database check not implemented"}
  end

  defp check_amqp do
    case Process.whereis(Vsmcp.AMQP.Connection) do
      nil ->
        {"amqp", :error, "AMQP connection not running"}
        
      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          {"amqp", :ok, "AMQP connection alive"}
        else
          {"amqp", :error, "AMQP connection dead"}
        end
    end
  end

  defp check_memory do
    memory = :erlang.memory(:total)
    limit = 2 * 1024 * 1024 * 1024  # 2GB
    
    if memory < limit do
      {"memory", :ok, "Memory usage: #{memory / 1_048_576}MB"}
    else
      {"memory", :warning, "High memory usage: #{memory / 1_048_576}MB"}
    end
  end

  defp check_processes do
    count = length(:erlang.processes())
    limit = 100_000
    
    if count < limit do
      {"processes", :ok, "Process count: #{count}"}
    else
      {"processes", :warning, "High process count: #{count}"}
    end
  end

  defp check_message_queues do
    large_queues = :erlang.processes()
    |> Enum.filter(fn pid ->
      case Process.info(pid, :message_queue_len) do
        {:message_queue_len, len} -> len > 1000
        _ -> false
      end
    end)
    |> length()
    
    if large_queues == 0 do
      {"message_queues", :ok, "No large message queues"}
    else
      {"message_queues", :warning, "#{large_queues} processes with large message queues"}
    end
  end

  defp test_single_mcp_connection(server_name) do
    case ServerRegistry.get_server_by_name(server_name) do
      nil ->
        {:error, "Server not found: #{server_name}"}
        
      server ->
        case ConnectionTester.test_server(server.id) do
          {:ok, latency} ->
            capabilities = ConnectionTester.test_capabilities(server.id)
            
            %{
              server: server_name,
              status: :connected,
              latency_ms: latency,
              capabilities_tested: length(capabilities),
              capabilities_passed: Enum.count(capabilities, fn {_, result} -> 
                elem(result, 0) == :ok 
              end)
            }
            
          {:error, reason} ->
            %{
              server: server_name,
              status: :failed,
              error: reason
            }
        end
    end
  end

  defp test_all_mcp_connections do
    servers = ServerRegistry.list_servers()
    
    results = Enum.map(servers, fn server ->
      case ConnectionTester.test_server(server.id) do
        {:ok, latency} ->
          %{
            server: server.name,
            status: :connected,
            latency_ms: latency
          }
          
        {:error, reason} ->
          %{
            server: server.name,
            status: :failed,
            error: reason
          }
      end
    end)
    
    %{
      total: length(results),
      connected: Enum.count(results, & &1.status == :connected),
      failed: Enum.count(results, & &1.status == :failed),
      servers: results
    }
  end

  defp format_status(status) do
    """
    VSMCP Status Report
    ===================
    
    Node: #{status.node}
    Uptime: #{status.uptime}
    Health: #{status.health}
    
    Memory Usage:
      Total: #{Float.round(status.memory.total_mb, 2)} MB
      Processes: #{Float.round(status.memory.processes_mb, 2)} MB
      System: #{Float.round(status.memory.system_mb, 2)} MB
    
    Processes:
      Total: #{status.processes.total}
      Schedulers: #{status.processes.schedulers}
      Run Queue: #{status.processes.run_queue}
    
    Cluster:
      Connected Nodes: #{status.cluster.connected_nodes}
      #{if status.cluster.connected_nodes > 0, do: "Nodes: #{inspect(status.cluster.nodes)}", else: ""}
    
    Applications: #{Enum.join(status.applications, ", ")}
    """
  end

  defp format_variety_report(report, :json) do
    Jason.encode!(report, pretty: true)
  end

  defp format_variety_report(report, :detailed) do
    """
    Detailed Variety Analysis
    ========================
    
    System Variety Score: #{report.system_variety.score}/100
    Environment Complexity: #{report.environment_variety.complexity}
    Coverage: #{report.analysis.coverage_percentage}%
    
    Critical Gaps:
    #{format_gaps(report.variety_gaps, :critical)}
    
    High Priority Gaps:
    #{format_gaps(report.variety_gaps, :high)}
    
    Current MCP Capabilities (#{length(report.current_capabilities)}):
    #{format_capabilities(report.current_capabilities)}
    
    Recommendations:
    #{format_recommendations(report.recommendations)}
    """
  end

  defp format_variety_report(report, _) do
    """
    Summary Report
    ==============
    
    Variety Gaps Detected: #{report.analysis.gap_count}
    Critical: #{count_by_severity(report.variety_gaps, :critical)}
    High: #{count_by_severity(report.variety_gaps, :high)}
    Medium: #{count_by_severity(report.variety_gaps, :medium)}
    Low: #{count_by_severity(report.variety_gaps, :low)}
    
    System Coverage: #{report.analysis.coverage_percentage}%
    
    Top Recommendations:
    #{format_recommendations(Enum.take(report.recommendations, 5))}
    
    Use 'detailed' or 'json' format for full report
    """
  end

  defp format_gaps(gaps, severity) do
    gaps
    |> Enum.filter(& &1.severity == severity)
    |> Enum.map(& "  - #{&1.name}: #{&1.description}")
    |> Enum.join("\n")
  end

  defp count_by_severity(gaps, severity) do
    Enum.count(gaps, & &1.severity == severity)
  end

  defp format_capabilities(capabilities) do
    capabilities
    |> Enum.map(& "  - #{&1.name} (#{&1.type})")
    |> Enum.join("\n")
  end

  defp format_recommendations(recommendations) do
    recommendations
    |> Enum.with_index(1)
    |> Enum.map(fn {r, i} -> "  #{i}. #{r.action}: #{r.capability}" end)
    |> Enum.join("\n")
  end

  defp format_duration(milliseconds) do
    seconds = div(milliseconds, 1000)
    minutes = div(seconds, 60)
    hours = div(minutes, 60)
    days = div(hours, 24)
    
    cond do
      days > 0 -> "#{days}d #{rem(hours, 24)}h #{rem(minutes, 60)}m"
      hours > 0 -> "#{hours}h #{rem(minutes, 60)}m #{rem(seconds, 60)}s"
      minutes > 0 -> "#{minutes}m #{rem(seconds, 60)}s"
      true -> "#{seconds}s"
    end
  end
end