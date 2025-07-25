# Path: lib/vsmcp/mcp/README.md
# VSMCP Hermes-MCP Integration

This directory contains the Hermes-MCP (Model Context Protocol) integration for VSMCP, enabling both server and client functionality with advanced tool chaining and variety acquisition capabilities.

## Architecture Overview

The Hermes-MCP integration provides:

1. **MCP Server** - Exposes VSM tools to external clients
2. **MCP Client** - Connects to external MCP servers
3. **Tool Chaining** - Composes multiple tools into workflows
4. **Capability Registry** - Discovers and acquires new capabilities
5. **System Adapters** - Bridges MCP tools into VSM systems
6. **Delegation Patterns** - Enables sub-VSM tool sharing

## Components

### Core Protocol (`protocol.ex`)
- Implements JSON-RPC 2.0 protocol
- Handles request/response parsing and encoding
- Provides error handling and protocol versioning

### MCP Server (`server.ex`)
- Exposes VSM tools via MCP protocol
- Supports stdio, TCP, and WebSocket transports
- Registers all VSM system tools (S1-S5)
- Handles variety management tools

### MCP Client (`client.ex`) 
- Connects to external MCP servers
- Discovers and lists available tools
- Executes remote tool calls
- Manages multiple server connections

### Tool Registry (`tool_registry.ex`)
- Central registry for all tools
- Validates tool definitions
- Executes tool handlers
- Tracks metrics and performance

### Tool Chain (`tool_chain.ex`)
- Composes tools into multi-step workflows
- Supports conditional execution
- Provides data transformation between steps
- Includes predefined chains for common patterns

### Capability Registry (`capability_registry.ex`)
- Discovers capabilities across local and external sources
- Matches requirements to available capabilities
- Calculates variety gaps
- Automates capability acquisition

### System Adapters
- **System1Adapter** (`adapters/system1_adapter.ex`) - Operational tool integration
- **System4Adapter** (`adapters/system4_adapter.ex`) - Intelligence source integration

### Delegation (`delegation.ex`)
- Manages hierarchical VSM structures
- Enables capability sharing between sub-VSMs
- Provides delegation rules and constraints
- Tracks usage metrics and audit trails

## Usage Examples

### Starting the MCP Server

```elixir
# The MCP server starts automatically with VSMCP
# It exposes VSM tools on stdio by default

# To start on TCP:
{:ok, _} = Vsmcp.MCP.Server.start_link(transport: :tcp, port: 3000)

# To start on WebSocket:
{:ok, _} = Vsmcp.MCP.Server.start_link(transport: :websocket, port: 8080)
```

### Connecting to External MCP Servers

```elixir
# Discover available servers
{:ok, servers} = Vsmcp.MCP.Client.discover_servers("github")

# Connect to a server
server_config = %{
  name: "github-mcp",
  transport: :stdio,
  command: "npx",
  args: ["@modelcontextprotocol/server-github"]
}

{:ok, server_id} = Vsmcp.MCP.Client.connect(server_config)

# List available tools
{:ok, tools} = Vsmcp.MCP.Client.list_tools(server_id)

# Call a tool
{:ok, result} = Vsmcp.MCP.Client.call_tool(
  server_id,
  "search_repos",
  %{"query" => "elixir vsm", "limit" => 10}
)
```

### Creating Tool Chains

```elixir
# Define a chain
chain_def = %{
  name: "data_analysis_pipeline",
  description: "Fetch, process, and analyze data",
  steps: [
    %{
      id: "fetch",
      tool: "http_request",
      source: {:external, "http-mcp"},
      args: %{url: "https://api.example.com/data"}
    },
    %{
      id: "transform",
      tool: "data_transform",
      source: {:external, "pandas-mcp"},
      transform: &extract_data/2
    },
    %{
      id: "analyze",
      tool: "vsm.s4.predict",
      source: :local,
      args: %{horizon: "1month"}
    }
  ]
}

{:ok, chain_id} = Vsmcp.MCP.ToolChain.create_chain(chain_def)

# Execute the chain
{:ok, execution_id} = Vsmcp.MCP.ToolChain.execute_chain(
  chain_id,
  %{initial_data: "context"}
)
```

### Capability Discovery and Acquisition

```elixir
# Define a requirement
requirement = %{
  id: "need_ml",
  capability_type: "machine_learning",
  priority: :high
}

# Discover matching capabilities
{:ok, matches} = Vsmcp.MCP.CapabilityRegistry.discover_capabilities(requirement)

# Acquire a capability
{:ok, acquisition} = Vsmcp.MCP.CapabilityRegistry.acquire_capability(
  hd(matches).capability.id
)

# Check variety gap
{:ok, gap} = Vsmcp.MCP.CapabilityRegistry.calculate_variety_gap()
```

### System Adapters

```elixir
# Register MCP tools as System 1 capabilities
Vsmcp.MCP.Adapters.System1Adapter.register_mcp_tool(%{
  capability_name: "external_api_call",
  mcp_server: "http-mcp",
  mcp_tool: "request",
  validation: &validate_api_params/1,
  transform: &transform_api_response/2
})

# Use adapted tool through System 1
{:ok, result} = Vsmcp.Systems.System1.execute(%{
  operations: [%{
    capability: "external_api_call",
    params: %{url: "https://api.example.com", method: "GET"}
  }]
})
```

### Sub-VSM Delegation

```elixir
# Create sub-VSMs
{:ok, vsm_dept_a} = Vsmcp.MCP.Delegation.register_sub_vsm(%{
  name: "Department A",
  level: 1
})

{:ok, vsm_dept_b} = Vsmcp.MCP.Delegation.register_sub_vsm(%{
  name: "Department B",
  level: 1
})

# Create delegation rule
{:ok, rule_id} = Vsmcp.MCP.Delegation.create_delegation_rule(%{
  from_vsm: vsm_dept_a,
  to_vsm: vsm_dept_b,
  capability_pattern: "*_analysis",
  constraints: %{max_calls_per_hour: 100}
})

# Request delegated capability
{:ok, result} = Vsmcp.MCP.Delegation.request_capability(
  vsm_dept_b,
  "data_analysis",
  %{dataset: "sales_2024"}
)
```

## Transport Options

### STDIO (Default)
- Best for command-line tools
- Simple integration with shell scripts
- No network configuration needed

### TCP
- Suitable for network services
- Supports multiple concurrent connections
- Uses Ranch for connection handling

### WebSocket
- Ideal for web applications
- Real-time bidirectional communication
- Uses Cowboy for HTTP/WebSocket

## Predefined Tool Chains

1. **variety_acquisition** - Discovers and integrates new capabilities
2. **intelligence_gathering** - Collects and analyzes external data
3. **operational_optimization** - Optimizes system performance

## Best Practices

1. **Tool Registration**
   - Always provide clear descriptions
   - Define input schemas for validation
   - Include error handling in handlers

2. **Capability Management**
   - Regular capability discovery
   - Monitor variety gaps
   - Automate acquisition when possible

3. **Delegation Rules**
   - Use specific patterns, not wildcards
   - Set appropriate constraints
   - Enable audit trails for compliance

4. **Performance**
   - Batch tool calls when possible
   - Use tool chains for complex workflows
   - Monitor metrics and optimize

## Configuration

The MCP subsystem can be configured in `config/config.exs`:

```elixir
config :vsmcp, :mcp,
  server_transport: :stdio,
  server_port: 3000,
  discovery_interval: 300_000,
  max_connections: 10,
  tool_timeout: 30_000
```

## Metrics and Monitoring

The MCP integration tracks:
- Tool execution counts and durations
- Capability registrations and acquisitions
- Delegation usage and performance
- Connection states and errors

Access metrics through:
```elixir
{:ok, metrics} = Vsmcp.MCP.ToolRegistry.get_metrics()
```

## Security Considerations

1. **Tool Validation** - All tools are validated before registration
2. **Capability Constraints** - Delegations can include usage limits
3. **Audit Trails** - Optional logging of all tool executions
4. **Sandboxing** - External tools run in isolated processes

## Troubleshooting

### Connection Issues
- Check server is running: `ps aux | grep mcp`
- Verify transport configuration
- Check firewall rules for TCP/WebSocket

### Tool Execution Failures
- Validate input parameters match schema
- Check tool handler errors in logs
- Verify external server connectivity

### Capability Discovery
- Ensure discovery interval is appropriate
- Check external server availability
- Monitor variety gap recommendations

## Future Enhancements

1. **Tool Marketplace** - Central registry of available MCP tools
2. **Capability Learning** - ML-based capability matching
3. **Federation** - Multi-VSM capability sharing
4. **Observability** - Enhanced tracing and debugging

For more information, see the [MCP Specification](https://modelcontextprotocol.io/specification).