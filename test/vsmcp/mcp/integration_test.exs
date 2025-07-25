# Path: test/vsmcp/mcp/integration_test.exs
defmodule Vsmcp.MCP.IntegrationTest do
  use ExUnit.Case
  
  alias Vsmcp.MCP.{Protocol, Server, Client, ToolRegistry, CapabilityRegistry}
  alias Vsmcp.MCP.{ToolChain, Delegation}
  alias Vsmcp.MCP.Adapters.{System1Adapter, System4Adapter}
  
  setup do
    # Start required services if not already started
    {:ok, _} = Application.ensure_all_started(:vsmcp)
    :ok
  end
  
  describe "MCP Protocol" do
    test "parses valid JSON-RPC requests" do
      request = ~s({"jsonrpc":"2.0","id":"test-1","method":"test","params":{}})
      
      assert {:ok, %Protocol.Request{id: "test-1", method: "test"}} = 
        Protocol.parse_message(request)
    end
    
    test "handles invalid JSON" do
      assert {:error, %Protocol.Error{code: -32700}} = 
        Protocol.parse_message("invalid json")
    end
    
    test "encodes responses correctly" do
      response = Protocol.success_response("test-1", %{result: "data"})
      encoded = Protocol.encode_message(response)
      
      assert encoded =~ ~s("id":"test-1")
      assert encoded =~ ~s("result":)
    end
  end
  
  describe "Tool Registry" do
    test "registers and executes tools" do
      tool_def = %{
        name: "test_tool",
        description: "Test tool",
        handler: fn args -> {:ok, Map.put(args, :processed, true)} end
      }
      
      assert :ok = ToolRegistry.register_tool(tool_def)
      
      assert {:ok, result} = ToolRegistry.call_tool("test_tool", %{input: "data"})
      assert result.processed == true
    end
    
    test "validates tool arguments" do
      tool_def = %{
        name: "validated_tool",
        description: "Tool with validation",
        handler: fn args -> {:ok, args} end,
        inputSchema: %{
          type: "object",
          required: ["required_field"]
        }
      }
      
      assert :ok = ToolRegistry.register_tool(tool_def)
      
      assert {:error, {:invalid_args, _}} = 
        ToolRegistry.call_tool("validated_tool", %{})
    end
  end
  
  describe "MCP Server" do
    test "handles tool listing" do
      request = ~s({
        "jsonrpc": "2.0",
        "id": "list-1",
        "method": "tools/list",
        "params": {}
      })
      
      {:ok, response} = Server.handle_message(request)
      decoded = Jason.decode!(response)
      
      assert decoded["id"] == "list-1"
      assert is_list(decoded["result"]["tools"])
    end
    
    test "exposes VSM tools" do
      {:ok, tools} = Server.list_tools()
      
      vsm_tools = Enum.filter(tools, &String.starts_with?(&1.name, "vsm."))
      assert length(vsm_tools) > 0
      
      # Check specific tools exist
      tool_names = Enum.map(tools, & &1.name)
      assert "vsm.s1.execute" in tool_names
      assert "vsm.s4.scan_environment" in tool_names
      assert "vsm.variety.calculate" in tool_names
    end
  end
  
  describe "Capability Registry" do
    test "discovers local capabilities" do
      # Register a test capability
      cap_def = %{
        name: "test_capability",
        type: "testing",
        source: %{type: :local}
      }
      
      {:ok, cap_id} = CapabilityRegistry.register_capability(cap_def)
      
      # Discover it
      requirement = %Vsmcp.MCP.CapabilityRegistry.Requirement{
        id: "test_req",
        capability_type: "testing"
      }
      
      {:ok, matches} = CapabilityRegistry.discover_capabilities(requirement)
      assert length(matches) > 0
      assert Enum.any?(matches, &(&1.capability.name == "test_capability"))
    end
    
    test "calculates variety gap" do
      {:ok, gap} = CapabilityRegistry.calculate_variety_gap()
      
      assert is_number(gap.current)
      assert is_number(gap.available)
      assert is_number(gap.required)
      assert is_list(gap.recommendations)
    end
  end
  
  describe "Tool Chains" do
    test "creates and lists chains" do
      chain_def = %{
        name: "test_chain",
        description: "Test chain",
        steps: [
          %{
            id: "step1",
            tool: "vsm.variety.calculate",
            source: :local,
            args: %{source: "test"}
          }
        ]
      }
      
      {:ok, chain_id} = ToolChain.create_chain(chain_def)
      
      chains = ToolChain.list_chains()
      assert Enum.any?(chains, &(&1.name == "test_chain"))
    end
    
    test "executes chains" do
      # Create a simple chain
      chain_def = %{
        name: "execution_test",
        steps: [
          %{
            id: "calculate",
            tool: "vsm.variety.calculate",
            source: :local,
            args: %{source: "test"}
          }
        ]
      }
      
      {:ok, chain_id} = ToolChain.create_chain(chain_def)
      {:ok, execution_id} = ToolChain.execute_chain(chain_id, %{})
      
      # Wait a bit for execution
      Process.sleep(100)
      
      {:ok, execution} = ToolChain.get_execution(execution_id)
      assert execution.status in [:running, :completed]
    end
  end
  
  describe "System Adapters" do
    test "registers MCP tools as S1 capabilities" do
      reg_def = %{
        capability_name: "test_s1_capability",
        mcp_server: "test-mcp",
        mcp_tool: "test_tool"
      }
      
      {:ok, reg_id} = System1Adapter.register_mcp_tool(reg_def)
      
      tools = System1Adapter.list_adapted_tools()
      assert Enum.any?(tools, &(&1.capability == "test_s1_capability"))
    end
    
    test "registers intelligence sources for S4" do
      source_def = %{
        name: "test_intelligence",
        type: :test_signals,
        mcp_server: "test-mcp",
        tools: ["scan", "analyze"]
      }
      
      {:ok, source_id} = System4Adapter.register_intelligence_source(source_def)
      
      sources = System4Adapter.list_intelligence_sources()
      assert Enum.any?(sources, &(&1.name == "test_intelligence"))
    end
  end
  
  describe "Delegation" do
    test "creates VSM hierarchy" do
      # Create sub-VSMs
      {:ok, vsm1} = Delegation.register_sub_vsm(%{
        name: "Test VSM 1",
        level: 1
      })
      
      {:ok, vsm2} = Delegation.register_sub_vsm(%{
        name: "Test VSM 2",
        level: 2,
        parent_id: vsm1
      })
      
      {:ok, hierarchy} = Delegation.get_vsm_hierarchy()
      assert hierarchy.name == "Root VSM"
      assert length(hierarchy.children) > 0
    end
    
    test "creates delegation rules" do
      # Create VSMs
      {:ok, from_vsm} = Delegation.register_sub_vsm(%{
        name: "Source VSM",
        level: 1
      })
      
      {:ok, to_vsm} = Delegation.register_sub_vsm(%{
        name: "Target VSM",
        level: 1
      })
      
      # Create rule
      rule_def = %{
        from_vsm: from_vsm,
        to_vsm: to_vsm,
        capability_pattern: "test_*"
      }
      
      {:ok, rule_id} = Delegation.create_delegation_rule(rule_def)
      
      delegations = Delegation.list_delegations(to_vsm)
      assert is_list(delegations)
    end
  end
  
  describe "Integration" do
    test "full variety acquisition flow" do
      # 1. Identify variety gap
      {:ok, gap} = CapabilityRegistry.calculate_variety_gap()
      initial_variety = gap.current
      
      # 2. Register new capability via adapter
      {:ok, _} = System1Adapter.register_mcp_tool(%{
        capability_name: "new_capability_#{:rand.uniform(1000)}",
        mcp_server: "test-mcp",
        mcp_tool: "new_tool"
      })
      
      # 3. Check variety increased
      {:ok, new_gap} = CapabilityRegistry.calculate_variety_gap()
      assert new_gap.available >= initial_variety
    end
  end
end