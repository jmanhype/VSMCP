defmodule VsmcpWeb.ApiController do
  use VsmcpWeb, :controller
  
  alias Vsmcp
  alias Vsmcp.Systems.{System1, System2, System3, System4, System5}

  def status(conn, _params) do
    status = Vsmcp.status()
    json(conn, status)
  end

  def system_status(conn, %{"system_id" => system_id}) do
    status = case system_id do
      "1" -> System1.status()
      "2" -> System2.status()
      "3" -> System3.status()
      "4" -> System4.status()
      "5" -> System5.status()
      _ -> {:error, "Invalid system ID"}
    end

    case status do
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
      
      status ->
        json(conn, status)
    end
  end
end