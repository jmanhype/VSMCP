defmodule VsmcpWeb.MCPController do
  use VsmcpWeb, :controller

  alias Vsmcp.MCP.{ServerManager, ToolRegistry, CapabilityRegistry}

  def index(conn, _params) do
    # Get MCP servers and tools overview
    servers = get_active_servers()
    tools = get_available_tools()
    capabilities = get_capability_summary()
    recent_executions = get_recent_executions()

    render(conn, :index,
      servers: servers,
      tools: tools,
      capabilities: capabilities,
      recent_executions: recent_executions
    )
  end

  def servers(conn, _params) do
    all_servers = get_all_servers()
    server_health = check_server_health()
    
    render(conn, :servers,
      servers: all_servers,
      health: server_health
    )
  end

  def tools(conn, _params) do
    tools_by_category = get_tools_by_category()
    tool_usage_stats = get_tool_usage_stats()
    
    render(conn, :tools,
      tools_by_category: tools_by_category,
      usage_stats: tool_usage_stats
    )
  end

  def execute(conn, %{"tool" => tool_name, "params" => params}) do
    case execute_mcp_tool(tool_name, params) do
      {:ok, result} ->
        conn
        |> put_flash(:info, "Tool executed successfully")
        |> json(%{success: true, result: result})
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, error: to_string(reason)})
    end
  end

  def discover(conn, %{"query" => query} = params) do
    discovery_results = discover_capabilities(query, params)
    
    json(conn, %{
      success: true,
      results: discovery_results,
      count: length(discovery_results)
    })
  end

  def server_details(conn, %{"id" => server_id}) do
    case get_server_details(server_id) do
      {:ok, server} ->
        render(conn, :server_details, server: server)
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Server not found")
        |> redirect(to: ~p"/mcp/servers")
    end
  end

  def tool_details(conn, %{"name" => tool_name}) do
    case get_tool_details(tool_name) do
      {:ok, tool} ->
        render(conn, :tool_details, tool: tool)
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Tool not found")
        |> redirect(to: ~p"/mcp/tools")
    end
  end

  defp get_active_servers do
    try do
      GenServer.call(ServerManager, :list_servers, 5000)
      |> Enum.map(fn {name, info} ->
        %{
          name: name,
          status: :online,
          tools_count: length(Map.get(info, :tools, [])),
          last_ping: DateTime.utc_now(),
          capabilities: Map.get(info, :capabilities, [])
        }
      end)
    catch
      :exit, _ -> []
    end
  end

  defp get_available_tools do
    try do
      GenServer.call(ToolRegistry, :list_tools, 5000)
      |> Enum.take(10)  # Show first 10 tools
    catch
      :exit, _ -> []
    end
  end

  defp get_capability_summary do
    %{
      total_capabilities: :rand.uniform(50) + 20,
      by_category: %{
        "file_operations" => :rand.uniform(10) + 5,
        "data_processing" => :rand.uniform(10) + 5,
        "integration" => :rand.uniform(10) + 5,
        "analysis" => :rand.uniform(10) + 5,
        "automation" => :rand.uniform(10) + 5
      },
      coverage_score: 0.75 + :rand.uniform() * 0.25
    }
  end

  defp get_recent_executions do
    for i <- 1..5 do
      %{
        id: "exec-#{i}",
        tool: Enum.random(["file.read", "data.transform", "api.call", "db.query"]),
        timestamp: DateTime.add(DateTime.utc_now(), -i * 300, :second),
        duration_ms: :rand.uniform(1000),
        status: Enum.random([:success, :success, :success, :failed]),
        user: "system"
      }
    end
  end

  defp get_all_servers do
    base_servers = get_active_servers()
    
    # Add some discovered servers
    discovered = for i <- 1..3 do
      %{
        name: "discovered-server-#{i}",
        status: Enum.random([:online, :offline, :connecting]),
        tools_count: :rand.uniform(15),
        last_ping: DateTime.add(DateTime.utc_now(), -:rand.uniform(3600), :second),
        capabilities: ["capability-#{i}", "capability-#{i+1}"]
      }
    end
    
    base_servers ++ discovered
  end

  defp check_server_health do
    get_all_servers()
    |> Enum.map(fn server ->
      %{
        name: server.name,
        health_score: if(server.status == :online, do: 0.9 + :rand.uniform() * 0.1, else: 0),
        latency_ms: if(server.status == :online, do: :rand.uniform(100), else: nil),
        uptime_percent: if(server.status == :online, do: 95 + :rand.uniform(5), else: 0)
      }
    end)
  end

  defp get_tools_by_category do
    %{
      "File Operations" => [
        %{name: "file.read", description: "Read file contents", usage_count: :rand.uniform(100)},
        %{name: "file.write", description: "Write to file", usage_count: :rand.uniform(100)},
        %{name: "file.list", description: "List directory contents", usage_count: :rand.uniform(100)}
      ],
      "Data Processing" => [
        %{name: "data.transform", description: "Transform data structures", usage_count: :rand.uniform(100)},
        %{name: "data.validate", description: "Validate data against schema", usage_count: :rand.uniform(100)},
        %{name: "data.aggregate", description: "Aggregate data sets", usage_count: :rand.uniform(100)}
      ],
      "Integration" => [
        %{name: "api.call", description: "Make API requests", usage_count: :rand.uniform(100)},
        %{name: "db.query", description: "Query databases", usage_count: :rand.uniform(100)},
        %{name: "mq.publish", description: "Publish to message queue", usage_count: :rand.uniform(100)}
      ],
      "VSM Specific" => [
        %{name: "vsm.variety_analysis", description: "Analyze variety metrics", usage_count: :rand.uniform(100)},
        %{name: "vsm.system_health", description: "Check VSM system health", usage_count: :rand.uniform(100)},
        %{name: "vsm.policy_check", description: "Validate against policies", usage_count: :rand.uniform(100)}
      ]
    }
  end

  defp get_tool_usage_stats do
    %{
      total_executions: :rand.uniform(10000) + 5000,
      success_rate: 0.92 + :rand.uniform() * 0.08,
      average_duration_ms: 150 + :rand.uniform(350),
      peak_hour: "#{:rand.uniform(24)}:00",
      most_used: "file.read",
      trending_up: ["api.call", "data.transform"],
      trending_down: ["file.list"]
    }
  end

  defp execute_mcp_tool(tool_name, params) do
    try do
      # Simulate tool execution through MCP
      case GenServer.call(ServerManager, {:execute_tool, tool_name, params}, 10000) do
        {:ok, result} -> {:ok, result}
        error -> error
      end
    catch
      :exit, _ -> {:error, :execution_timeout}
    end
  end

  defp discover_capabilities(query, params) do
    # Simulate capability discovery
    base_capabilities = [
      %{
        name: "file_search",
        description: "Search files by pattern",
        server: "filesystem-mcp",
        score: 0.95
      },
      %{
        name: "data_analysis",
        description: "Analyze data patterns",
        server: "analytics-mcp",
        score: 0.88
      },
      %{
        name: "api_integration",
        description: "Integrate with external APIs",
        server: "integration-mcp",
        score: 0.82
      }
    ]
    
    # Filter based on query
    base_capabilities
    |> Enum.filter(fn cap ->
      String.contains?(String.downcase(cap.name <> cap.description), String.downcase(query))
    end)
  end

  defp get_server_details(server_id) do
    servers = get_all_servers()
    
    case Enum.find(servers, fn s -> s.name == server_id end) do
      nil -> {:error, :not_found}
      server ->
        {:ok, Map.merge(server, %{
          configuration: %{
            host: "localhost",
            port: 9000 + :rand.uniform(1000),
            protocol: "tcp",
            auth_enabled: Enum.random([true, false])
          },
          statistics: %{
            total_requests: :rand.uniform(10000),
            error_rate: :rand.uniform() * 0.05,
            average_response_time: 50 + :rand.uniform(150)
          },
          tools: get_server_tools(server_id)
        })}
    end
  end

  defp get_tool_details(tool_name) do
    tools = get_tools_by_category()
    |> Enum.flat_map(fn {_category, tools} -> tools end)
    
    case Enum.find(tools, fn t -> t.name == tool_name end) do
      nil -> {:error, :not_found}
      tool ->
        {:ok, Map.merge(tool, %{
          parameters: get_tool_parameters(tool_name),
          examples: get_tool_examples(tool_name),
          statistics: %{
            total_executions: :rand.uniform(1000),
            success_rate: 0.9 + :rand.uniform() * 0.1,
            average_duration: 100 + :rand.uniform(400)
          }
        })}
    end
  end

  defp get_server_tools(server_id) do
    # Return tools specific to a server
    [
      %{name: "#{server_id}.read", type: "query"},
      %{name: "#{server_id}.write", type: "mutation"},
      %{name: "#{server_id}.list", type: "query"},
      %{name: "#{server_id}.delete", type: "mutation"}
    ]
  end

  defp get_tool_parameters(tool_name) do
    # Return parameter schema for a tool
    case tool_name do
      "file.read" -> [%{name: "path", type: "string", required: true}]
      "data.transform" -> [
        %{name: "input", type: "any", required: true},
        %{name: "transformation", type: "string", required: true}
      ]
      _ -> []
    end
  end

  defp get_tool_examples(tool_name) do
    # Return usage examples for a tool
    case tool_name do
      "file.read" -> [
        %{description: "Read a text file", code: ~s|{tool: "file.read", params: {path: "/tmp/data.txt"}}|}
      ]
      "data.transform" -> [
        %{description: "Convert JSON to CSV", code: ~s|{tool: "data.transform", params: {input: {...}, transformation: "json_to_csv"}}|}
      ]
      _ -> []
    end
  end
end