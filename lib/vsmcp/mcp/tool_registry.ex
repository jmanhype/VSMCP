# Path: lib/vsmcp/mcp/tool_registry.ex
defmodule Vsmcp.MCP.ToolRegistry do
  @moduledoc """
  Registry for MCP tools. Manages tool registration, discovery, and execution.
  """
  
  use GenServer
  require Logger

  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  def register_tool(registry \\ __MODULE__, tool_def) do
    GenServer.call(registry, {:register_tool, tool_def})
  end

  def unregister_tool(registry \\ __MODULE__, tool_name) do
    GenServer.call(registry, {:unregister_tool, tool_name})
  end

  def list_tools(registry \\ __MODULE__) do
    GenServer.call(registry, :list_tools)
  end

  def get_tool(registry \\ __MODULE__, tool_name) do
    GenServer.call(registry, {:get_tool, tool_name})
  end

  def call_tool(registry \\ __MODULE__, tool_name, args) do
    GenServer.call(registry, {:call_tool, tool_name, args})
  end

  def search_tools(registry \\ __MODULE__, query) do
    GenServer.call(registry, {:search_tools, query})
  end

  # Server Callbacks
  
  @impl true
  def init(_opts) do
    {:ok, %{
      tools: %{},
      capabilities: %{},
      metrics: %{
        calls: %{},
        errors: %{}
      }
    }}
  end

  @impl true
  def handle_call({:register_tool, tool_def}, _from, state) do
    case validate_tool_def(tool_def) do
      :ok ->
        tool_name = tool_def.name
        new_tools = Map.put(state.tools, tool_name, tool_def)
        new_capabilities = update_capabilities(state.capabilities, tool_def)
        
        new_state = %{state | 
          tools: new_tools,
          capabilities: new_capabilities
        }
        
        Logger.info("Registered tool: #{tool_name}")
        {:reply, :ok, new_state}
        
      {:error, reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:unregister_tool, tool_name}, _from, state) do
    new_tools = Map.delete(state.tools, tool_name)
    new_state = %{state | tools: new_tools}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:list_tools, _from, state) do
    tools = state.tools
    |> Map.values()
    |> Enum.map(&format_tool_info/1)
    
    {:reply, tools, state}
  end

  @impl true
  def handle_call({:get_tool, tool_name}, _from, state) do
    case Map.get(state.tools, tool_name) do
      nil -> {:reply, {:error, :not_found}, state}
      tool -> {:reply, {:ok, format_tool_info(tool)}, state}
    end
  end

  @impl true
  def handle_call({:call_tool, tool_name, args}, _from, state) do
    case Map.get(state.tools, tool_name) do
      nil ->
        {:reply, {:error, :not_found}, state}
        
      tool ->
        # Validate arguments against schema
        case validate_args(args, tool[:inputSchema]) do
          :ok ->
            # Execute tool handler
            start_time = System.monotonic_time()
            result = execute_tool(tool, args)
            duration = System.monotonic_time() - start_time
            
            # Update metrics
            new_state = update_metrics(state, tool_name, result, duration)
            
            {:reply, result, new_state}
            
          {:error, reason} ->
            {:reply, {:error, {:invalid_args, reason}}, state}
        end
    end
  end

  @impl true
  def handle_call({:search_tools, query}, _from, state) do
    # Simple search by name and description
    results = state.tools
    |> Map.values()
    |> Enum.filter(fn tool ->
      String.contains?(String.downcase(tool.name), String.downcase(query)) ||
      String.contains?(String.downcase(tool.description || ""), String.downcase(query))
    end)
    |> Enum.map(&format_tool_info/1)
    
    {:reply, results, state}
  end

  # Private Functions
  
  defp validate_tool_def(tool_def) do
    required_fields = [:name, :description, :handler]
    
    missing_fields = required_fields
    |> Enum.filter(fn field -> 
      !Map.has_key?(tool_def, field) || tool_def[field] == nil
    end)
    
    case missing_fields do
      [] -> 
        if is_function(tool_def.handler, 1) do
          :ok
        else
          {:error, "Handler must be a function with arity 1"}
        end
        
      fields -> 
        {:error, "Missing required fields: #{Enum.join(fields, ", ")}"}
    end
  end

  defp format_tool_info(tool) do
    %{
      name: tool.name,
      description: tool.description,
      inputSchema: tool[:inputSchema] || %{type: "object"}
    }
  end

  defp validate_args(args, nil), do: :ok
  defp validate_args(args, schema) do
    # Simple validation - check required fields
    required = schema[:required] || []
    
    missing = required
    |> Enum.filter(fn field -> 
      !Map.has_key?(args, field) && !Map.has_key?(args, to_string(field))
    end)
    
    case missing do
      [] -> :ok
      fields -> {:error, "Missing required fields: #{Enum.join(fields, ", ")}"}
    end
  end

  defp execute_tool(tool, args) do
    try do
      tool.handler.(args)
    rescue
      e ->
        Logger.error("Tool execution error: #{inspect(e)}")
        {:error, {:execution_error, Exception.message(e)}}
    end
  end

  defp update_capabilities(capabilities, tool_def) do
    # Extract capabilities from tool description
    keywords = extract_keywords(tool_def.description)
    
    Enum.reduce(keywords, capabilities, fn keyword, acc ->
      tools = Map.get(acc, keyword, [])
      Map.put(acc, keyword, [tool_def.name | tools])
    end)
  end

  defp extract_keywords(description) do
    # Simple keyword extraction
    description
    |> String.downcase()
    |> String.split(~r/\W+/)
    |> Enum.filter(fn word -> String.length(word) > 3 end)
    |> Enum.uniq()
  end

  defp update_metrics(state, tool_name, result, duration) do
    calls = Map.update(state.metrics.calls, tool_name, 1, &(&1 + 1))
    
    errors = case result do
      {:error, _} ->
        Map.update(state.metrics.errors, tool_name, 1, &(&1 + 1))
      _ ->
        state.metrics.errors
    end
    
    %{state | 
      metrics: %{
        calls: calls,
        errors: errors,
        last_call: %{
          tool: tool_name,
          duration: duration,
          timestamp: DateTime.utc_now()
        }
      }
    }
  end
end