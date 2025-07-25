# Path: lib/vsmcp/mcp/tool_chain.ex
defmodule Vsmcp.MCP.ToolChain do
  @moduledoc """
  Tool chaining mechanism for composing multiple MCP tools into workflows.
  Enables complex variety acquisition through tool composition.
  """
  
  use GenServer
  require Logger
  
  alias Vsmcp.MCP.{Client, ToolRegistry}

  # Chain definition structure
  defmodule Chain do
    @enforce_keys [:id, :name, :steps]
    defstruct [:id, :name, :description, :steps, :metadata]
  end

  defmodule Step do
    @enforce_keys [:id, :tool, :source]
    defstruct [:id, :tool, :source, :args, :transform, :condition, :retry]
  end

  defmodule Execution do
    @enforce_keys [:chain_id, :id]
    defstruct [:chain_id, :id, :status, :context, :results, :errors, :started_at, :completed_at]
  end

  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  def create_chain(server \\ __MODULE__, chain_def) do
    GenServer.call(server, {:create_chain, chain_def})
  end

  def execute_chain(server \\ __MODULE__, chain_id, initial_context \\ %{}) do
    GenServer.call(server, {:execute_chain, chain_id, initial_context}, :infinity)
  end

  def list_chains(server \\ __MODULE__) do
    GenServer.call(server, :list_chains)
  end

  def get_execution(server \\ __MODULE__, execution_id) do
    GenServer.call(server, {:get_execution, execution_id})
  end

  # Predefined chains for common patterns
  def create_predefined_chains(server \\ __MODULE__) do
    # Variety acquisition chain
    create_chain(server, %{
      name: "variety_acquisition",
      description: "Discover and integrate new capabilities",
      steps: [
        %{
          id: "scan",
          tool: "vsm.s4.scan_environment",
          source: :local,
          args: %{focus: "opportunities"}
        },
        %{
          id: "discover",
          tool: "vsm.variety.acquire",
          source: :local,
          args: %{source: "mcp"},
          transform: &extract_capability/2
        },
        %{
          id: "connect",
          tool: "mcp.client.connect",
          source: :internal,
          args: %{},
          transform: &prepare_connection/2
        },
        %{
          id: "integrate",
          tool: "vsm.s1.register_capability",
          source: :local,
          transform: &prepare_registration/2
        }
      ]
    })
    
    # Intelligence gathering chain
    create_chain(server, %{
      name: "intelligence_gathering",
      description: "Gather and analyze external intelligence",
      steps: [
        %{
          id: "identify_sources",
          tool: "vsm.s4.scan_environment",
          source: :local,
          args: %{focus: "all"}
        },
        %{
          id: "query_github",
          tool: "github.search_repos",
          source: {:external, "github-mcp"},
          condition: &has_github_signal?/1,
          transform: &extract_repos/2
        },
        %{
          id: "analyze_data",
          tool: "vsm.s4.predict",
          source: :local,
          args: %{horizon: "6months"},
          transform: &prepare_prediction/2
        },
        %{
          id: "suggest_action",
          tool: "vsm.s4.suggest_adaptation",
          source: :local,
          transform: &format_suggestion/2
        }
      ]
    })
    
    # Operational optimization chain
    create_chain(server, %{
      name: "operational_optimization",
      description: "Optimize operational performance",
      steps: [
        %{
          id: "audit",
          tool: "vsm.s3.audit",
          source: :local,
          args: %{unit: "all"}
        },
        %{
          id: "analyze_metrics",
          tool: "vsm.variety.calculate",
          source: :local,
          transform: &extract_bottlenecks/2
        },
        %{
          id: "find_tools",
          tool: "mcp.discover_servers",
          source: :internal,
          transform: &match_capabilities/2
        },
        %{
          id: "coordinate",
          tool: "vsm.s2.coordinate",
          source: :local,
          transform: &prepare_coordination/2
        }
      ]
    })
  end

  # Server Callbacks
  
  @impl true
  def init(opts) do
    client = opts[:client] || Client
    registry = opts[:registry] || ToolRegistry
    
    {:ok, %{
      chains: %{},
      executions: %{},
      client: client,
      registry: registry,
      metrics: %{
        chains_created: 0,
        executions_started: 0,
        executions_completed: 0,
        executions_failed: 0
      }
    }}
  end

  @impl true
  def handle_call({:create_chain, chain_def}, _from, state) do
    chain_id = generate_chain_id(chain_def)
    
    chain = %Chain{
      id: chain_id,
      name: chain_def.name,
      description: chain_def[:description],
      steps: Enum.map(chain_def.steps, &create_step/1),
      metadata: chain_def[:metadata] || %{}
    }
    
    new_chains = Map.put(state.chains, chain_id, chain)
    new_metrics = %{state.metrics | chains_created: state.metrics.chains_created + 1}
    
    {:reply, {:ok, chain_id}, %{state | chains: new_chains, metrics: new_metrics}}
  end

  @impl true
  def handle_call({:execute_chain, chain_id, initial_context}, _from, state) do
    case Map.get(state.chains, chain_id) do
      nil ->
        {:reply, {:error, :chain_not_found}, state}
        
      chain ->
        execution_id = generate_execution_id()
        
        execution = %Execution{
          id: execution_id,
          chain_id: chain_id,
          status: :running,
          context: initial_context,
          results: %{},
          errors: [],
          started_at: DateTime.utc_now()
        }
        
        # Start async execution
        Task.start_link(fn ->
          execute_steps(chain, execution, state)
        end)
        
        new_executions = Map.put(state.executions, execution_id, execution)
        new_metrics = %{state.metrics | executions_started: state.metrics.executions_started + 1}
        
        {:reply, {:ok, execution_id}, %{state | executions: new_executions, metrics: new_metrics}}
    end
  end

  @impl true
  def handle_call(:list_chains, _from, state) do
    chains = state.chains
    |> Map.values()
    |> Enum.map(fn chain ->
      %{
        id: chain.id,
        name: chain.name,
        description: chain.description,
        steps_count: length(chain.steps)
      }
    end)
    
    {:reply, chains, state}
  end

  @impl true
  def handle_call({:get_execution, execution_id}, _from, state) do
    case Map.get(state.executions, execution_id) do
      nil -> {:reply, {:error, :not_found}, state}
      execution -> {:reply, {:ok, execution}, state}
    end
  end

  # Private Functions
  
  defp generate_chain_id(chain_def) do
    "chain_#{chain_def.name}_#{:erlang.phash2(chain_def)}"
  end

  defp generate_execution_id do
    "exec_#{:erlang.unique_integer([:positive])}"
  end

  defp create_step(step_def) do
    %Step{
      id: step_def.id,
      tool: step_def.tool,
      source: step_def.source,
      args: step_def[:args] || %{},
      transform: step_def[:transform],
      condition: step_def[:condition],
      retry: step_def[:retry] || %{max_attempts: 3, delay: 1000}
    }
  end

  defp execute_steps(chain, execution, state) do
    final_execution = Enum.reduce(chain.steps, execution, fn step, acc_exec ->
      if should_execute_step?(step, acc_exec) do
        execute_single_step(step, acc_exec, state)
      else
        Logger.info("Skipping step #{step.id} due to condition")
        acc_exec
      end
    end)
    
    # Update execution status
    completed_execution = %{final_execution | 
      status: if(final_execution.errors == [], do: :completed, else: :failed),
      completed_at: DateTime.utc_now()
    }
    
    # Update state
    GenServer.cast(self(), {:execution_completed, completed_execution})
    
    completed_execution
  end

  defp should_execute_step?(step, execution) do
    case step.condition do
      nil -> true
      condition when is_function(condition, 1) -> condition.(execution.context)
      _ -> true
    end
  end

  defp execute_single_step(step, execution, state) do
    Logger.info("Executing step: #{step.id}")
    
    # Prepare arguments
    args = merge_args(step.args, execution.context)
    
    # Execute tool based on source
    result = case step.source do
      :local ->
        ToolRegistry.call_tool(state.registry, step.tool, args)
        
      :internal ->
        execute_internal_tool(step.tool, args, state)
        
      {:external, server_id} ->
        Client.call_tool(state.client, server_id, step.tool, args)
    end
    
    case result do
      {:ok, tool_result} ->
        # Apply transformation if provided
        transformed = case step.transform do
          nil -> tool_result
          transform when is_function(transform, 2) -> 
            transform.(tool_result, execution.context)
          _ -> tool_result
        end
        
        # Update execution
        %{execution |
          context: Map.merge(execution.context, %{step.id => transformed}),
          results: Map.put(execution.results, step.id, transformed)
        }
        
      {:error, error} ->
        Logger.error("Step #{step.id} failed: #{inspect(error)}")
        %{execution |
          errors: [{step.id, error} | execution.errors]
        }
    end
  end

  defp merge_args(step_args, context) do
    # Replace context references in args
    step_args
    |> Enum.map(fn {k, v} ->
      {k, resolve_value(v, context)}
    end)
    |> Map.new()
  end

  defp resolve_value({:context, path}, context) when is_binary(path) do
    get_in(context, String.split(path, "."))
  end

  defp resolve_value(value, _context), do: value

  defp execute_internal_tool("mcp.client.connect", args, state) do
    Client.connect(state.client, args)
  end

  defp execute_internal_tool("mcp.discover_servers", args, state) do
    Client.discover_servers(state.client, args["query"] || "")
  end

  # Transform functions for chains
  
  defp extract_capability(result, _context) do
    %{capability: result[:capability] || "unknown"}
  end

  defp prepare_connection(result, context) do
    %{
      server_config: %{
        name: result[:source] || context["scan"]["source"],
        transport: :stdio,
        command: result[:command] || "npx #{result[:source]}"
      }
    }
  end

  defp prepare_registration(result, context) do
    %{
      name: context["discover"]["capability"],
      handler: result[:handler] || fn args -> {:ok, args} end
    }
  end

  defp has_github_signal?(context) do
    signals = get_in(context, ["scan", "opportunities"]) || []
    Enum.any?(signals, fn signal -> 
      String.contains?(to_string(signal[:description] || ""), "github")
    end)
  end

  defp extract_repos(result, _context) do
    %{repositories: result[:items] || []}
  end

  defp prepare_prediction(result, context) do
    %{
      data: Map.merge(context["identify_sources"] || %{}, context["query_github"] || %{})
    }
  end

  defp format_suggestion(result, _context) do
    %{
      recommendations: result[:actions] || [],
      priority: result[:priority] || :normal
    }
  end

  defp extract_bottlenecks(result, context) do
    metrics = context["audit"]["metrics"] || %{}
    %{
      bottlenecks: identify_bottlenecks(metrics),
      required_capabilities: suggest_capabilities(metrics)
    }
  end

  defp identify_bottlenecks(metrics) do
    # Simple bottleneck identification
    if metrics[:failures] > metrics[:successes] do
      ["high_failure_rate"]
    else
      []
    end
  end

  defp suggest_capabilities(metrics) do
    # Suggest capabilities based on metrics
    suggestions = []
    
    suggestions = if metrics[:failures] > 0, do: ["error_handling" | suggestions], else: suggestions
    suggestions = if metrics[:executions] > 100, do: ["performance_optimization" | suggestions], else: suggestions
    
    suggestions
  end

  defp match_capabilities(result, context) do
    required = context["analyze_metrics"]["required_capabilities"] || []
    servers = result[:servers] || []
    
    %{
      matched_servers: Enum.filter(servers, fn server ->
        Enum.any?(required, fn cap ->
          cap in server.capabilities
        end)
      end)
    }
  end

  defp prepare_coordination(result, context) do
    %{
      units: ["system1", "system2"],
      action: "integrate_capabilities",
      tools: context["find_tools"]["matched_servers"] || []
    }
  end

  # Handle execution completion
  @impl true
  def handle_cast({:execution_completed, execution}, state) do
    new_executions = Map.put(state.executions, execution.id, execution)
    
    new_metrics = case execution.status do
      :completed ->
        %{state.metrics | executions_completed: state.metrics.executions_completed + 1}
      :failed ->
        %{state.metrics | executions_failed: state.metrics.executions_failed + 1}
    end
    
    {:noreply, %{state | executions: new_executions, metrics: new_metrics}}
  end
end