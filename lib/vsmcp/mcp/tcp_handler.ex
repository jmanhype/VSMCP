# Path: lib/vsmcp/mcp/tcp_handler.ex
defmodule Vsmcp.MCP.TCPHandler do
  @moduledoc """
  TCP handler for MCP server using Ranch.
  """
  
  use GenServer
  require Logger

  @behaviour :ranch_protocol

  def start_link(ref, socket, transport, opts) do
    pid = :proc_lib.spawn_link(__MODULE__, init, [{ref, socket, transport, opts}])
    {:ok, pid}
  end

  def init({ref, socket, transport, opts}) do
    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, [{:active, true}, {:packet, :line}])
    
    state = %{
      socket: socket,
      transport: transport,
      server: opts.server,
      buffer: ""
    }
    
    :gen_server.enter_loop(__MODULE__, [], state)
  end

  def handle_info({:tcp, socket, data}, %{socket: socket} = state) do
    # Handle incoming data
    case handle_data(data, state) do
      {:ok, response} ->
        state.transport.send(socket, response <> "\n")
        {:noreply, state}
        
      :ok ->
        {:noreply, state}
        
      {:error, reason} ->
        Logger.error("TCP handler error: #{inspect(reason)}")
        {:stop, :normal, state}
    end
  end

  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    Logger.info("TCP connection closed")
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, socket, reason}, %{socket: socket} = state) do
    Logger.error("TCP error: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  defp handle_data(data, state) do
    # Process JSON-RPC message
    trimmed = String.trim(data)
    
    if trimmed != "" do
      Vsmcp.MCP.Server.handle_message(state.server, trimmed)
    else
      :ok
    end
  end
end