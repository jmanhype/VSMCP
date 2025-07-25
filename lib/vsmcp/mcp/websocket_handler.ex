# Path: lib/vsmcp/mcp/websocket_handler.ex
defmodule Vsmcp.MCP.WebSocketHandler do
  @moduledoc """
  WebSocket handler for MCP server using Cowboy.
  """
  
  @behaviour :cowboy_websocket
  
  require Logger

  def init(req, opts) do
    {:cowboy_websocket, req, opts}
  end

  def websocket_init(opts) do
    state = %{
      server: opts.server
    }
    {:ok, state}
  end

  def websocket_handle({:text, message}, state) do
    case Vsmcp.MCP.Server.handle_message(state.server, message) do
      {:ok, response} ->
        {:reply, {:text, response}, state}
        
      :ok ->
        {:ok, state}
        
      {:error, reason} ->
        Logger.error("WebSocket handler error: #{inspect(reason)}")
        {:reply, {:text, Jason.encode!(%{error: to_string(reason)})}, state}
    end
  end

  def websocket_handle(_frame, state) do
    {:ok, state}
  end

  def websocket_info(_info, state) do
    {:ok, state}
  end

  def terminate(reason, _req, _state) do
    Logger.info("WebSocket connection terminated: #{inspect(reason)}")
    :ok
  end
end