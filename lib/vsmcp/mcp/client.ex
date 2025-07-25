# Path: lib/vsmcp/mcp/client.ex
defmodule Vsmcp.MCP.Client do
  @moduledoc """
  MCP Client for connecting to external MCP servers and acquiring their tools.
  Enables variety acquisition through tool discovery and integration.
  """
  
  use GenServer
  require Logger
  
  alias Vsmcp.MCP.{Protocol, Connection}

  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  def connect(client \\ __MODULE__, server_config) do
    GenServer.call(client, {:connect, server_config}, 30_000)
  end

  def disconnect(client \\ __MODULE__, server_id) do
    GenServer.call(client, {:disconnect, server_id})
  end

  def list_servers(client \\ __MODULE__) do
    GenServer.call(client, :list_servers)
  end

  def list_tools(client \\ __MODULE__, server_id) do
    GenServer.call(client, {:list_tools, server_id})
  end

  def call_tool(client \\ __MODULE__, server_id, tool_name, args) do
    GenServer.call(client, {:call_tool, server_id, tool_name, args}, 30_000)
  end

  def discover_servers(client \\ __MODULE__, query) do
    GenServer.call(client, {:discover_servers, query})
  end

  # Server Callbacks
  
  @impl true
  def init(_opts) do
    {:ok, %{
      connections: %{},
      discovered_tools: %{},
      metrics: %{
        connections: 0,
        tool_calls: 0,
        errors: 0
      }
    }}
  end

  @impl true
  def handle_call({:connect, config}, _from, state) do
    server_id = generate_server_id(config)
    
    case establish_connection(config) do
      {:ok, connection} ->
        # Initialize MCP session
        case initialize_session(connection) do
          {:ok, server_info} ->
            # Discover available tools
            case discover_tools(connection) do
              {:ok, tools} ->
                new_connections = Map.put(state.connections, server_id, %{
                  config: config,
                  connection: connection,
                  info: server_info,
                  tools: tools
                })
                
                new_discovered = Map.put(state.discovered_tools, server_id, tools)
                
                new_state = %{state |
                  connections: new_connections,
                  discovered_tools: new_discovered,
                  metrics: %{state.metrics | connections: state.metrics.connections + 1}
                }
                
                Logger.info("Connected to MCP server: #{server_id}")
                {:reply, {:ok, server_id}, new_state}
                
              {:error, reason} ->
                Connection.close(connection)
                {:reply, {:error, {:tool_discovery_failed, reason}}, state}
            end
            
          {:error, reason} ->
            Connection.close(connection)
            {:reply, {:error, {:initialization_failed, reason}}, state}
        end
        
      {:error, reason} ->
        {:reply, {:error, {:connection_failed, reason}}, state}
    end
  end

  @impl true
  def handle_call({:disconnect, server_id}, _from, state) do
    case Map.get(state.connections, server_id) do
      nil ->
        {:reply, {:error, :not_connected}, state}
        
      %{connection: connection} ->
        Connection.close(connection)
        new_connections = Map.delete(state.connections, server_id)
        new_discovered = Map.delete(state.discovered_tools, server_id)
        
        new_state = %{state |
          connections: new_connections,
          discovered_tools: new_discovered
        }
        
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:list_servers, _from, state) do
    servers = state.connections
    |> Enum.map(fn {id, conn} ->
      %{
        id: id,
        name: conn.info["serverInfo"]["name"],
        version: conn.info["serverInfo"]["version"],
        tools_count: length(conn.tools),
        connected_at: conn.info["timestamp"]
      }
    end)
    
    {:reply, servers, state}
  end

  @impl true
  def handle_call({:list_tools, server_id}, _from, state) do
    case Map.get(state.discovered_tools, server_id) do
      nil -> {:reply, {:error, :not_connected}, state}
      tools -> {:reply, {:ok, tools}, state}
    end
  end

  @impl true
  def handle_call({:call_tool, server_id, tool_name, args}, _from, state) do
    case Map.get(state.connections, server_id) do
      nil ->
        {:reply, {:error, :not_connected}, state}
        
      %{connection: connection} ->
        # Create tool call request
        request = %Protocol.Request{
          id: generate_request_id(),
          method: "tools/call",
          params: %{
            "name" => tool_name,
            "arguments" => args
          }
        }
        
        case Connection.send_request(connection, request) do
          {:ok, response} ->
            new_metrics = %{state.metrics | tool_calls: state.metrics.tool_calls + 1}
            {:reply, {:ok, response.result}, %{state | metrics: new_metrics}}
            
          {:error, error} ->
            new_metrics = %{state.metrics | errors: state.metrics.errors + 1}
            {:reply, {:error, error}, %{state | metrics: new_metrics}}
        end
    end
  end

  @impl true
  def handle_call({:discover_servers, query}, _from, state) do
    # Discover MCP servers (would integrate with registry/discovery service)
    discovered = [
      %{
        name: "filesystem-mcp",
        transport: :stdio,
        command: "npx @modelcontextprotocol/server-filesystem",
        args: ["/tmp"],
        capabilities: ["file_read", "file_write", "directory_list"]
      },
      %{
        name: "github-mcp",
        transport: :stdio,
        command: "npx @modelcontextprotocol/server-github",
        args: [],
        capabilities: ["repo_read", "issue_create", "pr_list"]
      },
      %{
        name: "postgres-mcp",
        transport: :stdio,
        command: "npx @modelcontextprotocol/server-postgres",
        args: ["postgresql://localhost/db"],
        capabilities: ["query", "schema_inspect"]
      }
    ]
    |> Enum.filter(fn server ->
      String.contains?(String.downcase(server.name), String.downcase(query)) ||
      Enum.any?(server.capabilities, &String.contains?(&1, String.downcase(query)))
    end)
    
    {:reply, {:ok, discovered}, state}
  end

  # Private Functions
  
  defp generate_server_id(config) do
    case config do
      %{name: name} -> name
      %{command: cmd} -> "mcp_#{:erlang.phash2(cmd)}"
      _ -> "mcp_#{:erlang.phash2(config)}"
    end
  end

  defp generate_request_id do
    "req_#{:erlang.phash2(:erlang.unique_integer())}"
  end

  defp establish_connection(config) do
    Connection.connect(config)
  end

  defp initialize_session(connection) do
    request = %Protocol.Request{
      id: generate_request_id(),
      method: "initialize",
      params: %{
        "protocolVersion" => "2024-11-05",
        "capabilities" => %{},
        "clientInfo" => %{
          "name" => "vsmcp-client",
          "version" => "0.1.0"
        }
      }
    }
    
    case Connection.send_request(connection, request) do
      {:ok, %{result: result}} ->
        # Send initialized notification
        notification = %Protocol.Notification{
          method: "notifications/initialized",
          params: %{}
        }
        Connection.send_notification(connection, notification)
        
        {:ok, Map.put(result, "timestamp", DateTime.utc_now())}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp discover_tools(connection) do
    request = %Protocol.Request{
      id: generate_request_id(),
      method: "tools/list",
      params: %{}
    }
    
    case Connection.send_request(connection, request) do
      {:ok, %{result: %{"tools" => tools}}} ->
        {:ok, tools}
        
      {:ok, %{error: error}} ->
        {:error, error}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
end

# Connection handler module
defmodule Vsmcp.MCP.Connection do
  @moduledoc """
  Handles MCP connection transports (stdio, tcp, websocket)
  """
  
  alias Vsmcp.MCP.Protocol
  
  def connect(%{transport: :stdio} = config) do
    # Start stdio process
    port = Port.open({:spawn_executable, config.command}, [
      :binary,
      :exit_status,
      :use_stdio,
      :hide,
      args: config[:args] || []
    ])
    
    {:ok, %{transport: :stdio, port: port, buffer: ""}}
  end

  def connect(%{transport: :tcp} = config) do
    opts = [:binary, active: false, packet: :line]
    case :gen_tcp.connect(config.host, config.port, opts) do
      {:ok, socket} ->
        {:ok, %{transport: :tcp, socket: socket, buffer: ""}}
      error ->
        error
    end
  end

  def connect(%{transport: :websocket} = config) do
    # WebSocket connection using websockex
    case WebSockex.start_link(config.url, __MODULE__, %{buffer: ""}) do
      {:ok, pid} ->
        {:ok, %{transport: :websocket, pid: pid, buffer: ""}}
      error ->
        error
    end
  end

  def send_request(conn, request) do
    message = Protocol.encode_message(request)
    
    case send_message(conn, message) do
      :ok ->
        # Wait for response with matching ID
        receive_response(conn, request.id)
      error ->
        error
    end
  end

  def send_notification(conn, notification) do
    message = Protocol.encode_message(notification)
    send_message(conn, message)
  end

  def close(%{transport: :stdio, port: port}) do
    Port.close(port)
  end

  def close(%{transport: :tcp, socket: socket}) do
    :gen_tcp.close(socket)
  end

  def close(%{transport: :websocket, pid: pid}) do
    WebSockex.stop(pid)
  end

  defp send_message(%{transport: :stdio, port: port}, message) do
    Port.command(port, message <> "\n")
    :ok
  end

  defp send_message(%{transport: :tcp, socket: socket}, message) do
    :gen_tcp.send(socket, message <> "\n")
  end

  defp send_message(%{transport: :websocket, pid: pid}, message) do
    WebSockex.send_frame(pid, {:text, message})
  end

  defp receive_response(conn, request_id, timeout \\ 30_000) do
    # Simplified - would implement proper response handling
    receive do
      {_port, {:data, data}} ->
        case Protocol.parse_message(data) do
          {:ok, %Protocol.Response{id: ^request_id} = response} ->
            {:ok, response}
          _ ->
            receive_response(conn, request_id, timeout)
        end
    after
      timeout ->
        {:error, :timeout}
    end
  end
end