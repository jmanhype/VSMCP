# Path: lib/vsmcp/mcp/protocol.ex
defmodule Vsmcp.MCP.Protocol do
  @moduledoc """
  MCP (Model Context Protocol) implementation for VSM.
  Handles JSON-RPC 2.0 protocol for tool communication.
  """
  
  require Logger
  alias Jason, as: JSON

  @protocol_version "2024-11-05"
  @implementation_name "VSMCP/hermes"
  @implementation_version "0.1.0"

  # JSON-RPC 2.0 message types
  defmodule Request do
    @enforce_keys [:id, :method, :params]
    defstruct [:id, :method, :params, jsonrpc: "2.0"]
  end

  defmodule Response do
    @enforce_keys [:id]
    defstruct [:id, :result, :error, jsonrpc: "2.0"]
  end

  defmodule Notification do
    @enforce_keys [:method, :params]
    defstruct [:method, :params, jsonrpc: "2.0"]
  end

  defmodule Error do
    @enforce_keys [:code, :message]
    defstruct [:code, :message, :data]
  end

  # Standard JSON-RPC error codes
  @parse_error -32700
  @invalid_request -32600
  @method_not_found -32601
  @invalid_params -32602
  @internal_error -32603

  @doc """
  Parse incoming JSON-RPC message
  """
  def parse_message(data) when is_binary(data) do
    case JSON.decode(data) do
      {:ok, %{"jsonrpc" => "2.0"} = msg} ->
        parse_json_rpc(msg)
      {:ok, _} ->
        {:error, error(@invalid_request, "Missing jsonrpc version")}
      {:error, _} ->
        {:error, error(@parse_error, "Invalid JSON")}
    end
  end

  defp parse_json_rpc(%{"method" => method, "params" => params, "id" => id}) do
    {:ok, %Request{id: id, method: method, params: params}}
  end

  defp parse_json_rpc(%{"method" => method, "params" => params}) do
    {:ok, %Notification{method: method, params: params}}
  end

  defp parse_json_rpc(%{"result" => result, "id" => id}) do
    {:ok, %Response{id: id, result: result}}
  end

  defp parse_json_rpc(%{"error" => error, "id" => id}) do
    {:ok, %Response{id: id, error: parse_error(error)}}
  end

  defp parse_json_rpc(_) do
    {:error, error(@invalid_request, "Invalid JSON-RPC message")}
  end

  defp parse_error(%{"code" => code, "message" => message} = error) do
    %Error{
      code: code,
      message: message,
      data: Map.get(error, "data")
    }
  end

  @doc """
  Encode JSON-RPC message
  """
  def encode_message(%Request{} = req) do
    %{
      jsonrpc: req.jsonrpc,
      id: req.id,
      method: req.method,
      params: req.params
    }
    |> JSON.encode!()
  end

  def encode_message(%Response{} = resp) do
    msg = %{jsonrpc: resp.jsonrpc, id: resp.id}
    
    msg = if resp.result != nil do
      Map.put(msg, :result, resp.result)
    else
      Map.put(msg, :error, encode_error(resp.error))
    end
    
    JSON.encode!(msg)
  end

  def encode_message(%Notification{} = notif) do
    %{
      jsonrpc: notif.jsonrpc,
      method: notif.method,
      params: notif.params
    }
    |> JSON.encode!()
  end

  defp encode_error(%Error{} = error) do
    %{
      code: error.code,
      message: error.message
    }
    |> then(fn msg ->
      if error.data != nil do
        Map.put(msg, :data, error.data)
      else
        msg
      end
    end)
  end

  @doc """
  Create error response
  """
  def error(code, message, data \\ nil) do
    %Error{code: code, message: message, data: data}
  end

  @doc """
  Create success response
  """
  def success_response(id, result) do
    %Response{id: id, result: result}
  end

  @doc """
  Create error response
  """
  def error_response(id, error) do
    %Response{id: id, error: error}
  end

  @doc """
  Get protocol information
  """
  def protocol_info do
    %{
      protocolVersion: @protocol_version,
      implementation: %{
        name: @implementation_name,
        version: @implementation_version
      }
    }
  end

  @doc """
  Standard error constructors
  """
  def method_not_found(method) do
    error(@method_not_found, "Method not found: #{method}")
  end

  def invalid_params(message) do
    error(@invalid_params, "Invalid params: #{message}")
  end

  def internal_error(message) do
    error(@internal_error, "Internal error: #{message}")
  end
end