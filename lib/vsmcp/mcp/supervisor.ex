# Path: lib/vsmcp/mcp/supervisor.ex
defmodule Vsmcp.MCP.Supervisor do
  @moduledoc """
  Supervisor for the MCP (Model Context Protocol) subsystem.
  Manages all MCP-related processes including server, client, and tool management.
  """
  
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Core MCP components
      {Vsmcp.MCP.ToolRegistry, name: Vsmcp.MCP.ToolRegistry},
      {Vsmcp.MCP.CapabilityRegistry, name: Vsmcp.MCP.CapabilityRegistry},
      
      # MCP Server (exposes VSM tools)
      {Vsmcp.MCP.Server, [
        name: Vsmcp.MCP.Server,
        transport: :stdio,
        port: 3000,
        registry: Vsmcp.MCP.ToolRegistry
      ]},
      
      # MCP Client (connects to external tools)
      {Vsmcp.MCP.Client, name: Vsmcp.MCP.Client},
      
      # Tool chaining
      {Vsmcp.MCP.ToolChain, [
        name: Vsmcp.MCP.ToolChain,
        client: Vsmcp.MCP.Client,
        registry: Vsmcp.MCP.ToolRegistry
      ]},
      
      # Adapters
      {Vsmcp.MCP.Adapters.System1Adapter, [
        name: Vsmcp.MCP.Adapters.System1Adapter,
        client: Vsmcp.MCP.Client,
        capability_registry: Vsmcp.MCP.CapabilityRegistry
      ]},
      
      {Vsmcp.MCP.Adapters.System4Adapter, [
        name: Vsmcp.MCP.Adapters.System4Adapter,
        client: Vsmcp.MCP.Client,
        capability_registry: Vsmcp.MCP.CapabilityRegistry,
        tool_chain: Vsmcp.MCP.ToolChain
      ]},
      
      # LLM Adapter for System 4 Intelligence
      {Vsmcp.MCP.Adapters.LLMAdapter, [
        name: Vsmcp.MCP.Adapters.LLMAdapter,
        client: Vsmcp.MCP.Client,
        capability_registry: Vsmcp.MCP.CapabilityRegistry
      ]},
      
      # LLM Feedback Loop for System 3 control
      # TODO: Fix Publisher module reference before enabling
      # {Vsmcp.MCP.Feedback.LLMFeedbackLoop, [
      #   name: Vsmcp.MCP.Feedback.LLMFeedbackLoop,
      #   auto_feedback: true
      # ]},
      
      # Delegation patterns
      {Vsmcp.MCP.Delegation, [
        name: Vsmcp.MCP.Delegation,
        server: Vsmcp.MCP.Server,
        client: Vsmcp.MCP.Client,
        tool_registry: Vsmcp.MCP.ToolRegistry,
        capability_registry: Vsmcp.MCP.CapabilityRegistry
      ]},
      
      # Original server manager for backward compatibility
      {Vsmcp.MCP.ServerManager, name: Vsmcp.MCP.ServerManager}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end