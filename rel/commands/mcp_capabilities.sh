#!/bin/bash
# Manage MCP capabilities

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Command: list, install, remove, discover, test
COMMAND=${1:-list}
shift || true

case "$COMMAND" in
  list)
    echo "MCP Capabilities"
    echo "==============="
    echo ""
    
    "$RELEASE_ROOT/bin/vsmcp" rpc "
      alias Vsmcp.MCP.{CapabilityManager, ServerRegistry}
      
      servers = ServerRegistry.list_servers()
      
      Enum.each(servers, fn server ->
        IO.puts(\"\\n#{server.name} (#{server.status}):\")
        IO.puts(\"  Type: #{server.type}\")
        IO.puts(\"  Version: #{server.version}\")
        IO.puts(\"  Capabilities:\")
        
        capabilities = CapabilityManager.get_capabilities(server.id)
        Enum.each(capabilities, fn cap ->
          IO.puts(\"    - #{cap.name}: #{cap.description}\")
        end)
      end)
      
      total_caps = servers
        |> Enum.flat_map(& CapabilityManager.get_capabilities(&1.id))
        |> length()
        
      IO.puts(\"\\nTotal capabilities: #{total_caps}\")
      :ok
    "
    ;;
    
  install)
    SERVER_NAME=$1
    if [[ -z "$SERVER_NAME" ]]; then
      echo "Usage: $0 install <server-name>"
      exit 1
    fi
    
    echo "Installing MCP server: $SERVER_NAME"
    
    "$RELEASE_ROOT/bin/vsmcp" rpc "
      alias Vsmcp.MCP.{Installer, ServerRegistry}
      
      case Installer.install_server(\"$SERVER_NAME\") do
        {:ok, server} ->
          IO.puts(\"✓ Successfully installed #{server.name}\")
          IO.puts(\"  Version: #{server.version}\")
          IO.puts(\"  Capabilities: #{length(server.capabilities)}\")
          :ok
          
        {:error, reason} ->
          IO.puts(\"✗ Failed to install: #{inspect(reason)}\")
          System.halt(1)
      end
    "
    ;;
    
  remove)
    SERVER_NAME=$1
    if [[ -z "$SERVER_NAME" ]]; then
      echo "Usage: $0 remove <server-name>"
      exit 1
    fi
    
    echo "Removing MCP server: $SERVER_NAME"
    
    "$RELEASE_ROOT/bin/vsmcp" rpc "
      alias Vsmcp.MCP.{Installer, ServerRegistry}
      
      case Installer.remove_server(\"$SERVER_NAME\") do
        :ok ->
          IO.puts(\"✓ Successfully removed #{\"$SERVER_NAME\"}\")
          
        {:error, reason} ->
          IO.puts(\"✗ Failed to remove: #{inspect(reason)}\")
          System.halt(1)
      end
    "
    ;;
    
  discover)
    echo "Discovering available MCP servers..."
    echo ""
    
    "$RELEASE_ROOT/bin/vsmcp" rpc "
      alias Vsmcp.MCP.Discovery
      
      servers = Discovery.discover_servers()
      
      IO.puts(\"Found #{length(servers)} available servers:\\n\")
      
      Enum.each(servers, fn server ->
        installed = if server.installed, do: \"[INSTALLED]\", else: \"\"
        IO.puts(\"  #{server.name} #{installed}\")
        IO.puts(\"    Description: #{server.description}\")
        IO.puts(\"    Capabilities: #{Enum.join(server.capabilities, \", \")}\")
        IO.puts(\"\")
      end)
      
      :ok
    "
    ;;
    
  test)
    SERVER_NAME=$1
    if [[ -z "$SERVER_NAME" ]]; then
      echo "Testing all MCP connections..."
      
      "$RELEASE_ROOT/bin/vsmcp" rpc "
        alias Vsmcp.MCP.{ServerRegistry, ConnectionTester}
        
        servers = ServerRegistry.list_servers()
        
        results = Enum.map(servers, fn server ->
          IO.write(\"Testing #{server.name}... \")
          
          case ConnectionTester.test_server(server.id) do
            {:ok, latency} ->
              IO.puts(\"✓ OK (#{latency}ms)\")
              {:ok, server.name, latency}
              
            {:error, reason} ->
              IO.puts(\"✗ FAILED (#{inspect(reason)})\")
              {:error, server.name, reason}
          end
        end)
        
        ok_count = Enum.count(results, fn {status, _, _} -> status == :ok end)
        
        IO.puts(\"\\nSummary: #{ok_count}/#{length(results)} servers operational\")
        
        if ok_count < length(results), do: System.halt(1), else: :ok
      "
    else
      echo "Testing MCP server: $SERVER_NAME"
      
      "$RELEASE_ROOT/bin/vsmcp" rpc "
        alias Vsmcp.MCP.{ServerRegistry, ConnectionTester}
        
        case ServerRegistry.get_server_by_name(\"$SERVER_NAME\") do
          nil ->
            IO.puts(\"Server not found: $SERVER_NAME\")
            System.halt(1)
            
          server ->
            IO.write(\"Testing connection... \")
            
            case ConnectionTester.test_server(server.id) do
              {:ok, latency} ->
                IO.puts(\"✓ OK (#{latency}ms)\")
                
                IO.puts(\"\\nTesting capabilities:\")
                capabilities = ConnectionTester.test_capabilities(server.id)
                
                Enum.each(capabilities, fn {cap_name, result} ->
                  status = if elem(result, 0) == :ok, do: \"✓\", else: \"✗\"
                  IO.puts(\"  #{status} #{cap_name}\")
                end)
                
              {:error, reason} ->
                IO.puts(\"✗ FAILED\")
                IO.puts(\"Error: #{inspect(reason)}\")
                System.halt(1)
            end
        end
      "
    fi
    ;;
    
  *)
    echo "Usage: $0 {list|install|remove|discover|test} [args]"
    echo ""
    echo "Commands:"
    echo "  list              List installed MCP servers and capabilities"
    echo "  install <name>    Install an MCP server"
    echo "  remove <name>     Remove an MCP server"
    echo "  discover          Discover available MCP servers"
    echo "  test [name]       Test MCP server connections"
    exit 1
    ;;
esac

exit 0