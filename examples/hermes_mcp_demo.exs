# Path: examples/hermes_mcp_demo.exs
# Hermes-MCP Integration Demo
# Demonstrates server/client chaining, tool composition, and variety acquisition

defmodule HermesMCPDemo do
  @moduledoc """
  Demonstration of Hermes-MCP integration in VSMCP.
  Shows how VSM can both expose and consume MCP tools.
  """
  
  alias Vsmcp.MCP.{Server, Client, ToolChain, CapabilityRegistry, Delegation}
  alias Vsmcp.MCP.Adapters.{System1Adapter, System4Adapter}
  alias Vsmcp.Systems.{System1, System4}
  
  def run do
    IO.puts("\n=== Hermes-MCP Integration Demo ===\n")
    
    # Ensure VSMCP is running
    ensure_vsmcp_started()
    
    # Demo 1: Expose VSM tools via MCP server
    demo_mcp_server()
    
    # Demo 2: Connect to external MCP servers
    demo_mcp_client()
    
    # Demo 3: Tool chaining for complex workflows
    demo_tool_chaining()
    
    # Demo 4: Capability discovery and acquisition
    demo_capability_acquisition()
    
    # Demo 5: System adapters
    demo_system_adapters()
    
    # Demo 6: Sub-VSM delegation
    demo_delegation_patterns()
    
    IO.puts("\n=== Demo Complete ===\n")
  end
  
  defp ensure_vsmcp_started do
    case Application.ensure_all_started(:vsmcp) do
      {:ok, _} -> IO.puts("✓ VSMCP started successfully")
      {:error, reason} -> 
        IO.puts("✗ Failed to start VSMCP: #{inspect(reason)}")
        System.halt(1)
    end
  end
  
  defp demo_mcp_server do
    IO.puts("\n--- Demo 1: MCP Server (Exposing VSM Tools) ---")
    
    # List available VSM tools
    {:ok, tools} = Server.list_tools()
    
    IO.puts("Available VSM tools via MCP:")
    Enum.each(tools, fn tool ->
      IO.puts("  • #{tool.name}: #{tool.description}")
    end)
    
    # Simulate external client calling VSM tool
    IO.puts("\nSimulating external MCP client request...")
    
    request = ~s({
      "jsonrpc": "2.0",
      "id": "demo-1",
      "method": "tools/call",
      "params": {
        "name": "vsm.s4.scan_environment",
        "arguments": {
          "context": {"source": "demo"},
          "focus": "opportunities"
        }
      }
    })
    
    {:ok, response} = Server.handle_message(request)
    IO.puts("Response: #{response}")
  end
  
  defp demo_mcp_client do
    IO.puts("\n--- Demo 2: MCP Client (Connecting to External Tools) ---")
    
    # Discover available MCP servers
    {:ok, servers} = Client.discover_servers("file")
    
    IO.puts("Discovered MCP servers:")
    Enum.each(servers, fn server ->
      IO.puts("  • #{server.name}: #{inspect(server.capabilities)}")
    end)
    
    # Connect to a server (simulated)
    IO.puts("\nConnecting to filesystem-mcp...")
    
    # In real scenario, would connect to actual MCP server
    # For demo, we'll simulate the connection
    server_config = %{
      name: "filesystem-mcp-demo",
      transport: :stdio,
      command: "echo", # Simulated
      args: ["MCP server simulation"]
    }
    
    case Client.connect(server_config) do
      {:ok, server_id} ->
        IO.puts("✓ Connected to server: #{server_id}")
        
        # List tools from connected server
        case Client.list_tools(server_id) do
          {:ok, tools} ->
            IO.puts("Available tools: #{length(tools)}")
          _ ->
            IO.puts("(Simulated - no actual tools)")
        end
        
      {:error, reason} ->
        IO.puts("✗ Connection failed (expected in demo): #{inspect(reason)}")
    end
  end
  
  defp demo_tool_chaining do
    IO.puts("\n--- Demo 3: Tool Chaining ---")
    
    # Create predefined chains
    ToolChain.create_predefined_chains()
    
    # List available chains
    chains = ToolChain.list_chains()
    
    IO.puts("Available tool chains:")
    Enum.each(chains, fn chain ->
      IO.puts("  • #{chain.name}: #{chain.description} (#{chain.steps_count} steps)")
    end)
    
    # Execute variety acquisition chain
    IO.puts("\nExecuting variety acquisition chain...")
    
    context = %{
      "requirements" => ["data_processing", "api_integration"],
      "constraints" => %{"source" => "mcp"}
    }
    
    case ToolChain.execute_chain("variety_acquisition", context) do
      {:ok, execution_id} ->
        IO.puts("✓ Chain execution started: #{execution_id}")
        
        # Check execution status
        Process.sleep(100) # Let it process
        
        case ToolChain.get_execution(execution_id) do
          {:ok, execution} ->
            IO.puts("  Status: #{execution.status}")
            IO.puts("  Results: #{inspect(Map.keys(execution.results))}")
          _ ->
            IO.puts("  (Execution in progress)")
        end
        
      {:error, reason} ->
        IO.puts("✗ Chain execution failed: #{inspect(reason)}")
    end
  end
  
  defp demo_capability_acquisition do
    IO.puts("\n--- Demo 4: Capability Discovery & Acquisition ---")
    
    # Define a requirement
    requirement = %Vsmcp.MCP.CapabilityRegistry.Requirement{
      id: "demo_req_1",
      capability_type: "data_transformation",
      priority: :high,
      constraints: %{}
    }
    
    # Discover capabilities
    {:ok, matches} = CapabilityRegistry.discover_capabilities(requirement)
    
    IO.puts("Discovered capabilities for '#{requirement.capability_type}':")
    Enum.take(matches, 5) |> Enum.each(fn match ->
      cap = match.capability
      IO.puts("  • #{cap.name} (#{cap.source.type})")
      IO.puts("    Score: #{match.score}, Source: #{inspect(cap.source)}")
    end)
    
    # Calculate variety gap
    {:ok, gap} = CapabilityRegistry.calculate_variety_gap()
    
    IO.puts("\nVariety Gap Analysis:")
    IO.puts("  Current variety: #{gap.current}")
    IO.puts("  Available variety: #{gap.available}")
    IO.puts("  Required variety: #{gap.required}")
    IO.puts("  Gap: #{gap.gap}")
    IO.puts("  Recommendations:")
    Enum.each(gap.recommendations, fn rec ->
      IO.puts("    - #{rec}")
    end)
  end
  
  defp demo_system_adapters do
    IO.puts("\n--- Demo 5: System Adapters ---")
    
    # Register common adapters
    IO.puts("Registering MCP tool adapters for System 1...")
    System1Adapter.register_common_adapters()
    
    tools = System1Adapter.list_adapted_tools()
    IO.puts("Registered #{length(tools)} tool adapters")
    
    Enum.take(tools, 3) |> Enum.each(fn tool ->
      IO.puts("  • #{tool.capability}: #{tool.mcp_server} -> #{tool.mcp_tool}")
    end)
    
    # Register intelligence sources
    IO.puts("\nRegistering intelligence sources for System 4...")
    System4Adapter.register_common_sources()
    
    sources = System4Adapter.list_intelligence_sources()
    IO.puts("Registered #{length(sources)} intelligence sources")
    
    Enum.each(sources, fn source ->
      IO.puts("  • #{source.name} (#{source.type}): #{source.tools_count} tools, #{source.scan_pattern} scan")
    end)
    
    # Simulate environmental scan with MCP
    IO.puts("\nPerforming environmental scan with MCP sources...")
    
    case System4Adapter.scan_with_mcp(%{demo: true}) do
      {:ok, results} ->
        IO.puts("✓ Scan complete:")
        IO.puts("  Total signals: #{results.summary.total_signals}")
        IO.puts("  Opportunities: #{length(results.opportunities)}")
        IO.puts("  Threats: #{length(results.threats)}")
        
      {:error, reason} ->
        IO.puts("✗ Scan failed: #{inspect(reason)}")
    end
  end
  
  defp demo_delegation_patterns do
    IO.puts("\n--- Demo 6: Sub-VSM Delegation ---")
    
    # Register sub-VSMs
    IO.puts("Creating VSM hierarchy...")
    
    # Level 1 - Operational units
    {:ok, vsm_ops1} = Delegation.register_sub_vsm(%{
      name: "Operations Unit 1",
      level: 1
    })
    
    {:ok, vsm_ops2} = Delegation.register_sub_vsm(%{
      name: "Operations Unit 2", 
      level: 1
    })
    
    # Level 2 - Coordination
    {:ok, vsm_coord} = Delegation.register_sub_vsm(%{
      name: "Coordination Layer",
      level: 2
    })
    
    IO.puts("✓ Created VSM hierarchy")
    
    # Create delegation rules
    IO.puts("\nCreating delegation rules...")
    
    {:ok, rule_id} = Delegation.create_delegation_rule(%{
      from_vsm: vsm_ops1,
      to_vsm: vsm_coord,
      capability_pattern: "vsm_#{vsm_ops1}_*",
      constraints: %{},
      audit_trail: true
    })
    
    IO.puts("✓ Created delegation rule: #{rule_id}")
    
    # Show VSM hierarchy
    {:ok, hierarchy} = Delegation.get_vsm_hierarchy()
    
    IO.puts("\nVSM Hierarchy:")
    print_hierarchy(hierarchy, 0)
    
    # List delegations
    delegations = Delegation.list_delegations(vsm_coord)
    
    IO.puts("\nActive delegations for #{vsm_coord}:")
    Enum.each(delegations, fn del ->
      IO.puts("  • #{del.capability} from #{del.from}")
    end)
  end
  
  defp print_hierarchy(node, level) do
    indent = String.duplicate("  ", level)
    IO.puts("#{indent}├─ #{node.name} (Level #{node.level})")
    IO.puts("#{indent}│  Capabilities: #{length(node.capabilities)}")
    IO.puts("#{indent}│  Metrics: R:#{node.metrics.requests} DR:#{node.metrics.delegations_received} DP:#{node.metrics.delegations_provided}")
    
    Enum.each(node.children, fn child ->
      print_hierarchy(child, level + 1)
    end)
  end
end

# Run the demo
HermesMCPDemo.run()