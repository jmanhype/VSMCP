# Path: lib/vsmcp/mcp/server_manager.ex
defmodule Vsmcp.MCP.ServerManager do
  @moduledoc """
  Manages MCP (Model Context Protocol) server connections and capabilities.
  """
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def list_servers do
    GenServer.call(__MODULE__, :list_servers)
  end

  def add_server(server_config) do
    GenServer.call(__MODULE__, {:add_server, server_config})
  end

  @impl true
  def init(_opts) do
    {:ok, %{
      servers: %{},
      capabilities: %{}
    }}
  end

  @impl true
  def handle_call(:list_servers, _from, state) do
    {:reply, Map.values(state.servers), state}
  end

  @impl true
  def handle_call({:add_server, config}, _from, state) do
    server_id = generate_server_id(config)
    new_servers = Map.put(state.servers, server_id, config)
    {:reply, {:ok, server_id}, %{state | servers: new_servers}}
  end

  defp generate_server_id(config) do
    "mcp_server_#{:erlang.phash2(config)}"
  end
end