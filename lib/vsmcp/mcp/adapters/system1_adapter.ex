# Path: lib/vsmcp/mcp/adapters/system1_adapter.ex
defmodule Vsmcp.MCP.Adapters.System1Adapter do
  @moduledoc """
  MCP adapter for System 1 operations.
  Bridges external MCP tools into VSM operational capabilities.
  """
  
  use GenServer
  require Logger
  
  alias Vsmcp.Systems.System1
  alias Vsmcp.MCP.{Client, CapabilityRegistry}

  # Adapter registration
  defmodule Registration do
    @enforce_keys [:id, :capability_name, :mcp_server, :mcp_tool]
    defstruct [:id, :capability_name, :mcp_server, :mcp_tool, :transform, :validation, :metadata]
  end

  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  def register_mcp_tool(adapter \\ __MODULE__, registration_def) do
    GenServer.call(adapter, {:register_mcp_tool, registration_def})
  end

  def create_operation(adapter \\ __MODULE__, capability_name, params) do
    GenServer.call(adapter, {:create_operation, capability_name, params})
  end

  def list_adapted_tools(adapter \\ __MODULE__) do
    GenServer.call(adapter, :list_adapted_tools)
  end

  # Predefined adapters for common MCP tools
  def register_common_adapters(adapter \\ __MODULE__) do
    # File system operations
    register_mcp_tool(adapter, %{
      capability_name: "file_operations",
      mcp_server: "filesystem-mcp",
      mcp_tool: "read_file",
      transform: &transform_file_read/2,
      validation: &validate_file_params/1
    })
    
    register_mcp_tool(adapter, %{
      capability_name: "file_write",
      mcp_server: "filesystem-mcp",
      mcp_tool: "write_file",
      transform: &transform_file_write/2,
      validation: &validate_file_write_params/1
    })
    
    # Database operations
    register_mcp_tool(adapter, %{
      capability_name: "database_query",
      mcp_server: "postgres-mcp",
      mcp_tool: "query",
      transform: &transform_db_query/2,
      validation: &validate_db_params/1
    })
    
    # API operations
    register_mcp_tool(adapter, %{
      capability_name: "http_request",
      mcp_server: "http-mcp",
      mcp_tool: "request",
      transform: &transform_http_request/2,
      validation: &validate_http_params/1
    })
    
    # GitHub operations
    register_mcp_tool(adapter, %{
      capability_name: "github_repo_info",
      mcp_server: "github-mcp",
      mcp_tool: "get_repo",
      transform: &transform_github_repo/2,
      validation: &validate_github_params/1
    })
    
    # Data processing
    register_mcp_tool(adapter, %{
      capability_name: "data_transform",
      mcp_server: "pandas-mcp",
      mcp_tool: "transform",
      transform: &transform_data_processing/2,
      validation: &validate_data_params/1
    })
  end

  # Server Callbacks
  
  @impl true
  def init(opts) do
    client = opts[:client] || Client
    capability_registry = opts[:capability_registry] || CapabilityRegistry
    
    {:ok, %{
      registrations: %{},
      client: client,
      capability_registry: capability_registry,
      metrics: %{
        tools_registered: 0,
        operations_created: 0,
        operations_executed: 0,
        errors: 0
      }
    }}
  end

  @impl true
  def handle_call({:register_mcp_tool, reg_def}, _from, state) do
    registration = create_registration(reg_def)
    
    # Register as System 1 capability
    handler = create_s1_handler(registration, state)
    System1.register_capability(registration.capability_name, handler)
    
    # Register in capability registry
    CapabilityRegistry.register_capability(state.capability_registry, %{
      name: registration.capability_name,
      type: :operational,
      source: %{type: :adapted, adapter: __MODULE__},
      interface: %{
        handler: handler,
        schema: build_schema(registration)
      },
      metadata: %{
        mcp_server: registration.mcp_server,
        mcp_tool: registration.mcp_tool
      }
    })
    
    new_registrations = Map.put(state.registrations, registration.id, registration)
    new_metrics = %{state.metrics | tools_registered: state.metrics.tools_registered + 1}
    
    Logger.info("Registered MCP tool adapter: #{registration.capability_name}")
    
    {:reply, {:ok, registration.id}, %{state | registrations: new_registrations, metrics: new_metrics}}
  end

  @impl true
  def handle_call({:create_operation, capability_name, params}, _from, state) do
    operation = %{
      capability: capability_name,
      params: params,
      metadata: %{
        source: :mcp_adapter,
        created_at: DateTime.utc_now()
      }
    }
    
    new_metrics = %{state.metrics | operations_created: state.metrics.operations_created + 1}
    
    {:reply, {:ok, operation}, %{state | metrics: new_metrics}}
  end

  @impl true
  def handle_call(:list_adapted_tools, _from, state) do
    tools = state.registrations
    |> Map.values()
    |> Enum.map(fn reg ->
      %{
        id: reg.id,
        capability: reg.capability_name,
        mcp_server: reg.mcp_server,
        mcp_tool: reg.mcp_tool
      }
    end)
    
    {:reply, tools, state}
  end

  # Private Functions
  
  defp create_registration(reg_def) do
    %Registration{
      id: generate_registration_id(reg_def),
      capability_name: reg_def.capability_name,
      mcp_server: reg_def.mcp_server,
      mcp_tool: reg_def.mcp_tool,
      transform: reg_def[:transform] || fn result, _params -> result end,
      validation: reg_def[:validation] || fn _params -> :ok end,
      metadata: reg_def[:metadata] || %{}
    }
  end

  defp generate_registration_id(reg_def) do
    "s1_adapter_#{reg_def.capability_name}_#{:erlang.phash2(reg_def)}"
  end

  defp create_s1_handler(registration, state) do
    fn operation ->
      execute_adapted_operation(operation, registration, state)
    end
  end

  defp execute_adapted_operation(operation, registration, state) do
    params = operation[:params] || operation.params || %{}
    
    # Validate parameters
    case registration.validation.(params) do
      :ok ->
        # Execute MCP tool
        case call_mcp_tool(registration, params, state) do
          {:ok, result} ->
            # Transform result for System 1
            transformed = registration.transform.(result, params)
            
            # Update metrics
            GenServer.cast(self(), :increment_executions)
            
            {:ok, transformed}
            
          {:error, reason} = error ->
            # Update error metrics
            GenServer.cast(self(), :increment_errors)
            
            Logger.error("MCP tool execution failed: #{inspect(reason)}")
            error
        end
        
      {:error, validation_error} ->
        {:error, {:validation_failed, validation_error}}
    end
  end

  defp call_mcp_tool(registration, params, state) do
    # Ensure connection to MCP server
    case ensure_mcp_connection(registration.mcp_server, state) do
      {:ok, server_id} ->
        # Call the MCP tool
        Client.call_tool(state.client, server_id, registration.mcp_tool, params)
        
      error ->
        error
    end
  end

  defp ensure_mcp_connection(server_name, state) do
    # Check if already connected
    case Client.list_servers(state.client) do
      servers when is_list(servers) ->
        case Enum.find(servers, &(&1.name == server_name)) do
          %{id: server_id} -> {:ok, server_id}
          nil -> connect_to_mcp_server(server_name, state)
        end
        
      _ ->
        connect_to_mcp_server(server_name, state)
    end
  end

  defp connect_to_mcp_server(server_name, state) do
    # Discover and connect to server
    case Client.discover_servers(state.client, server_name) do
      {:ok, [server | _]} ->
        Client.connect(state.client, server)
        
      _ ->
        {:error, {:server_not_found, server_name}}
    end
  end

  defp build_schema(registration) do
    # Build JSON schema for the adapted capability
    base_schema = %{
      type: "object",
      properties: %{},
      required: []
    }
    
    # Add schema based on capability type
    case registration.capability_name do
      "file_" <> _ ->
        %{base_schema | 
          properties: %{
            path: %{type: "string", description: "File path"},
            content: %{type: "string", description: "File content"}
          },
          required: ["path"]
        }
        
      "database_" <> _ ->
        %{base_schema |
          properties: %{
            query: %{type: "string", description: "SQL query"},
            params: %{type: "array", description: "Query parameters"}
          },
          required: ["query"]
        }
        
      "http_" <> _ ->
        %{base_schema |
          properties: %{
            url: %{type: "string", description: "URL"},
            method: %{type: "string", enum: ["GET", "POST", "PUT", "DELETE"]},
            headers: %{type: "object"},
            body: %{type: "object"}
          },
          required: ["url", "method"]
        }
        
      _ ->
        base_schema
    end
  end

  # Transform functions
  
  defp transform_file_read(result, _params) do
    %{
      type: :file_content,
      content: extract_content(result),
      metadata: %{
        size: byte_size(extract_content(result)),
        timestamp: DateTime.utc_now()
      }
    }
  end

  defp transform_file_write(result, params) do
    %{
      type: :file_written,
      path: params["path"] || params[:path],
      success: result != nil,
      timestamp: DateTime.utc_now()
    }
  end

  defp transform_db_query(result, _params) do
    %{
      type: :query_result,
      rows: extract_rows(result),
      row_count: length(extract_rows(result)),
      metadata: extract_metadata(result)
    }
  end

  defp transform_http_request(result, _params) do
    %{
      type: :http_response,
      status: extract_status(result),
      headers: extract_headers(result),
      body: extract_body(result)
    }
  end

  defp transform_github_repo(result, _params) do
    %{
      type: :github_repo,
      data: result,
      summary: %{
        name: result["name"],
        stars: result["stargazers_count"],
        language: result["language"]
      }
    }
  end

  defp transform_data_processing(result, _params) do
    %{
      type: :processed_data,
      data: result,
      shape: determine_shape(result),
      timestamp: DateTime.utc_now()
    }
  end

  # Validation functions
  
  defp validate_file_params(params) do
    if params["path"] || params[:path] do
      :ok
    else
      {:error, "Missing required parameter: path"}
    end
  end

  defp validate_file_write_params(params) do
    cond do
      !(params["path"] || params[:path]) ->
        {:error, "Missing required parameter: path"}
      !(params["content"] || params[:content]) ->
        {:error, "Missing required parameter: content"}
      true ->
        :ok
    end
  end

  defp validate_db_params(params) do
    if params["query"] || params[:query] do
      :ok
    else
      {:error, "Missing required parameter: query"}
    end
  end

  defp validate_http_params(params) do
    cond do
      !(params["url"] || params[:url]) ->
        {:error, "Missing required parameter: url"}
      !(params["method"] || params[:method]) ->
        {:error, "Missing required parameter: method"}
      true ->
        :ok
    end
  end

  defp validate_github_params(params) do
    if params["repo"] || params[:repo] do
      :ok
    else
      {:error, "Missing required parameter: repo"}
    end
  end

  defp validate_data_params(params) do
    if params["data"] || params[:data] do
      :ok
    else
      {:error, "Missing required parameter: data"}
    end
  end

  # Helper functions
  
  defp extract_content(result) do
    case result do
      %{"content" => [%{"text" => text}]} -> text
      %{"content" => content} when is_binary(content) -> content
      text when is_binary(text) -> text
      _ -> ""
    end
  end

  defp extract_rows(result) do
    case result do
      %{"rows" => rows} -> rows
      rows when is_list(rows) -> rows
      _ -> []
    end
  end

  defp extract_metadata(result) do
    case result do
      %{"metadata" => metadata} -> metadata
      _ -> %{}
    end
  end

  defp extract_status(result) do
    case result do
      %{"status" => status} -> status
      _ -> 200
    end
  end

  defp extract_headers(result) do
    case result do
      %{"headers" => headers} -> headers
      _ -> %{}
    end
  end

  defp extract_body(result) do
    case result do
      %{"body" => body} -> body
      %{"content" => content} -> content
      _ -> nil
    end
  end

  defp determine_shape(data) do
    case data do
      list when is_list(list) -> %{type: :list, length: length(list)}
      map when is_map(map) -> %{type: :map, keys: Map.keys(map)}
      _ -> %{type: :unknown}
    end
  end

  # Handle metric updates
  @impl true
  def handle_cast(:increment_executions, state) do
    new_metrics = %{state.metrics | operations_executed: state.metrics.operations_executed + 1}
    {:noreply, %{state | metrics: new_metrics}}
  end

  @impl true
  def handle_cast(:increment_errors, state) do
    new_metrics = %{state.metrics | errors: state.metrics.errors + 1}
    {:noreply, %{state | metrics: new_metrics}}
  end
end