# Path: lib/vsmcp/mcp/server.ex
defmodule Vsmcp.MCP.Server do
  @moduledoc """
  MCP Server for exposing VSM tools to external clients.
  Implements the Model Context Protocol server specification.
  """
  
  use GenServer
  require Logger
  
  alias Vsmcp.MCP.{Protocol, ToolRegistry}
  alias Vsmcp.Systems.{System1, System2, System3, System4, System5}

  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  def handle_message(server \\ __MODULE__, message) do
    GenServer.call(server, {:handle_message, message})
  end

  def list_tools(server \\ __MODULE__) do
    GenServer.call(server, :list_tools)
  end

  # Server Callbacks
  
  @impl true
  def init(opts) do
    port = opts[:port] || 3000
    
    # Use the existing tool registry from supervisor
    registry = opts[:registry] || Vsmcp.MCP.ToolRegistry
    register_vsm_tools(registry)
    
    state = %{
      port: port,
      registry: registry,
      sessions: %{},
      transport: opts[:transport] || :stdio
    }
    
    # Start transport based on configuration
    case state.transport do
      :stdio -> start_stdio_transport(state)
      :tcp -> start_tcp_transport(state)
      :websocket -> start_websocket_transport(state)
      _ -> {:ok, state}
    end
  end

  @impl true
  def handle_call({:handle_message, data}, _from, state) do
    case Protocol.parse_message(data) do
      {:ok, %Protocol.Request{} = req} ->
        response = handle_request(req, state)
        {:reply, {:ok, Protocol.encode_message(response)}, state}
        
      {:ok, %Protocol.Notification{} = notif} ->
        handle_notification(notif, state)
        {:reply, :ok, state}
        
      {:error, error} ->
        response = Protocol.error_response(nil, error)
        {:reply, {:ok, Protocol.encode_message(response)}, state}
    end
  end

  @impl true
  def handle_call(:list_tools, _from, state) do
    tools = ToolRegistry.list_tools(state.registry)
    {:reply, {:ok, tools}, state}
  end

  # Private Functions
  
  defp handle_request(%Protocol.Request{method: "initialize", id: id} = req, state) do
    result = %{
      protocolVersion: "2024-11-05",
      capabilities: %{
        tools: %{},
        logging: %{}
      },
      serverInfo: %{
        name: "vsmcp-server",
        version: "0.1.0"
      }
    }
    
    Protocol.success_response(id, result)
  end

  defp handle_request(%Protocol.Request{method: "tools/list", id: id}, state) do
    tools = ToolRegistry.list_tools(state.registry)
    Protocol.success_response(id, %{tools: tools})
  end

  defp handle_request(%Protocol.Request{method: "tools/call", id: id, params: params}, state) do
    tool_name = params["name"]
    tool_args = params["arguments"] || %{}
    
    case ToolRegistry.call_tool(state.registry, tool_name, tool_args) do
      {:ok, result} ->
        Protocol.success_response(id, %{
          content: [%{
            type: "text",
            text: format_result(result)
          }]
        })
        
      {:error, :not_found} ->
        Protocol.error_response(id, Protocol.method_not_found(tool_name))
        
      {:error, reason} ->
        Protocol.error_response(id, Protocol.internal_error(inspect(reason)))
    end
  end

  defp handle_request(%Protocol.Request{method: method, id: id}, _state) do
    Protocol.error_response(id, Protocol.method_not_found(method))
  end

  defp handle_notification(%Protocol.Notification{method: "notifications/initialized"}, _state) do
    Logger.info("MCP client initialized")
  end

  defp handle_notification(%Protocol.Notification{method: method}, _state) do
    Logger.debug("Received notification: #{method}")
  end

  defp register_vsm_tools(registry) do
    # System 1: Operations tools
    ToolRegistry.register_tool(registry, %{
      name: "vsm.s1.execute",
      description: "Execute operational task in System 1",
      inputSchema: %{
        type: "object",
        properties: %{
          capability: %{type: "string", description: "Capability to execute"},
          params: %{type: "object", description: "Parameters for the operation"}
        },
        required: ["capability"]
      },
      handler: &s1_execute/1
    })
    
    ToolRegistry.register_tool(registry, %{
      name: "vsm.s1.register_capability",
      description: "Register new operational capability in System 1",
      inputSchema: %{
        type: "object",
        properties: %{
          name: %{type: "string", description: "Capability name"},
          description: %{type: "string", description: "What this capability does"}
        },
        required: ["name"]
      },
      handler: &s1_register_capability/1
    })
    
    # System 2: Coordination tools
    ToolRegistry.register_tool(registry, %{
      name: "vsm.s2.coordinate",
      description: "Coordinate activities across operational units",
      inputSchema: %{
        type: "object",
        properties: %{
          units: %{type: "array", items: %{type: "string"}},
          action: %{type: "string", description: "Coordination action"}
        },
        required: ["units", "action"]
      },
      handler: &s2_coordinate/1
    })
    
    # System 3: Control tools
    ToolRegistry.register_tool(registry, %{
      name: "vsm.s3.audit",
      description: "Audit operational performance",
      inputSchema: %{
        type: "object",
        properties: %{
          unit: %{type: "string", description: "Unit to audit"},
          metrics: %{type: "array", items: %{type: "string"}}
        },
        required: ["unit"]
      },
      handler: &s3_audit/1
    })
    
    # System 4: Intelligence tools
    ToolRegistry.register_tool(registry, %{
      name: "vsm.s4.scan_environment",
      description: "Scan environment for opportunities and threats",
      inputSchema: %{
        type: "object",
        properties: %{
          context: %{type: "object", description: "Environmental context"},
          focus: %{type: "string", enum: ["opportunities", "threats", "all"]}
        }
      },
      handler: &s4_scan_environment/1
    })
    
    ToolRegistry.register_tool(registry, %{
      name: "vsm.s4.predict",
      description: "Predict future scenarios",
      inputSchema: %{
        type: "object",
        properties: %{
          horizon: %{type: "string", description: "Time horizon (e.g. '6months', '1year')"},
          domain: %{type: "string", description: "Domain to predict"}
        },
        required: ["horizon"]
      },
      handler: &s4_predict/1
    })
    
    # System 5: Policy tools
    ToolRegistry.register_tool(registry, %{
      name: "vsm.s5.set_policy",
      description: "Set organizational policy",
      inputSchema: %{
        type: "object",
        properties: %{
          policy: %{type: "object", description: "Policy definition"},
          scope: %{type: "string", enum: ["global", "system", "unit"]}
        },
        required: ["policy"]
      },
      handler: &s5_set_policy/1
    })
    
    # Variety management tools
    ToolRegistry.register_tool(registry, %{
      name: "vsm.variety.calculate",
      description: "Calculate variety metrics",
      inputSchema: %{
        type: "object",
        properties: %{
          source: %{type: "string", description: "Variety source"},
          constraints: %{type: "array", items: %{type: "string"}}
        },
        required: ["source"]
      },
      handler: &calculate_variety/1
    })
    
    ToolRegistry.register_tool(registry, %{
      name: "vsm.variety.acquire",
      description: "Acquire new variety through tool discovery",
      inputSchema: %{
        type: "object",
        properties: %{
          capability: %{type: "string", description: "Required capability"},
          source: %{type: "string", enum: ["mcp", "api", "library"]}
        },
        required: ["capability"]
      },
      handler: &acquire_variety/1
    })
  end

  # Tool handlers
  
  defp s1_execute(args) do
    coordination = %{
      operations: [%{
        capability: args["capability"],
        params: args["params"] || %{}
      }]
    }
    
    case System1.execute(coordination) do
      [{:ok, result}] -> {:ok, result}
      [{:error, reason}] -> {:error, reason}
      results -> {:ok, results}
    end
  end

  defp s1_register_capability(args) do
    # For now, return success - would integrate with actual handler registration
    {:ok, %{
      registered: args["name"],
      description: args["description"]
    }}
  end

  defp s2_coordinate(args) do
    # Simplified coordination
    {:ok, %{
      coordinated: args["units"],
      action: args["action"],
      status: "synchronized"
    }}
  end

  defp s3_audit(args) do
    # Get metrics from System 1
    case System1.status() do
      {:ok, state} ->
        {:ok, %{
          unit: args["unit"],
          metrics: state.metrics,
          timestamp: DateTime.utc_now()
        }}
      error -> error
    end
  end

  defp s4_scan_environment(args) do
    context = args["context"] || %{}
    System4.scan_environment(context)
  end

  defp s4_predict(args) do
    System4.predict_future(args["horizon"])
  end

  defp s5_set_policy(args) do
    # Simplified policy setting
    {:ok, %{
      policy: args["policy"],
      scope: args["scope"] || "global",
      applied: DateTime.utc_now()
    }}
  end

  defp calculate_variety(args) do
    # Use the variety calculator
    source = args["source"]
    constraints = args["constraints"] || []
    
    {:ok, %{
      source: source,
      variety: :rand.uniform(100), # Simplified
      constraints: constraints,
      recommendations: ["acquire_tools", "reduce_constraints"]
    }}
  end

  defp acquire_variety(args) do
    capability = args["capability"]
    source = args["source"] || "mcp"
    
    # This would trigger the MCP client to find and connect to new tools
    {:ok, %{
      capability: capability,
      source: source,
      status: "searching",
      candidates: ["tool1", "tool2", "tool3"]
    }}
  end

  defp format_result(result) do
    case result do
      {:ok, data} -> "Success: #{inspect(data)}"
      {:error, reason} -> "Error: #{inspect(reason)}"
      data -> inspect(data)
    end
  end

  # Transport initialization
  
  defp start_stdio_transport(state) do
    # STDIO transport reads from stdin and writes to stdout
    Task.start_link(fn -> stdio_loop(self()) end)
    {:ok, state}
  end

  defp start_tcp_transport(state) do
    # TCP transport listens on specified port
    {:ok, _pid} = :ranch.start_listener(
      :mcp_tcp,
      :ranch_tcp,
      %{port: state.port},
      Vsmcp.MCP.TCPHandler,
      %{server: self()}
    )
    Logger.info("MCP TCP server listening on port #{state.port}")
    {:ok, state}
  end

  defp start_websocket_transport(state) do
    # WebSocket transport using Cowboy
    dispatch = :cowboy_router.compile([
      {:_, [
        {"/mcp", Vsmcp.MCP.WebSocketHandler, %{server: self()}}
      ]}
    ])
    
    {:ok, _pid} = :cowboy.start_clear(
      :mcp_websocket,
      [{:port, state.port}],
      %{env: %{dispatch: dispatch}}
    )
    Logger.info("MCP WebSocket server listening on port #{state.port}")
    {:ok, state}
  end

  defp stdio_loop(server) do
    case IO.gets("") do
      :eof -> :ok
      {:error, _} -> :ok
      data ->
        data = String.trim(data)
        if data != "" do
          case handle_message(server, data) do
            {:ok, response} -> IO.puts(response)
            _ -> :ok
          end
        end
        stdio_loop(server)
    end
  end
end