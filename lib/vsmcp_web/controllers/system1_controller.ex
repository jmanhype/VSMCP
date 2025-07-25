defmodule VsmcpWeb.System1Controller do
  use VsmcpWeb, :controller

  alias Vsmcp.Systems.System1

  def index(conn, _params) do
    # Get System1 state and operational data
    state = get_system_state()
    operations = get_recent_operations()
    metrics = get_operational_metrics()

    render(conn, :index,
      state: state,
      operations: operations,
      metrics: metrics
    )
  end

  def show(conn, %{"id" => operation_id}) do
    case get_operation_details(operation_id) do
      {:ok, operation} ->
        render(conn, :show, operation: operation)
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Operation not found")
        |> redirect(to: ~p"/system1")
    end
  end

  def execute(conn, %{"command" => command} = params) do
    case System1.execute_operation(command, params) do
      {:ok, result} ->
        conn
        |> put_flash(:info, "Operation executed successfully")
        |> json(%{success: true, result: result})
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, error: to_string(reason)})
    end
  end

  defp get_system_state do
    try do
      GenServer.call(System1, :get_state, 5000)
    catch
      :exit, _ -> %{status: :offline, operations: [], metrics: %{}}
    end
  end

  defp get_recent_operations do
    # Fetch recent operations from System1
    try do
      GenServer.call(System1, {:get_operations, limit: 10}, 5000)
    catch
      :exit, _ -> []
    end
  end

  defp get_operational_metrics do
    %{
      throughput: :rand.uniform(1000),
      latency: :rand.uniform(100),
      success_rate: 0.95 + :rand.uniform() * 0.05,
      active_operations: :rand.uniform(50)
    }
  end

  defp get_operation_details(operation_id) do
    # Fetch specific operation details
    try do
      case GenServer.call(System1, {:get_operation, operation_id}, 5000) do
        nil -> {:error, :not_found}
        operation -> {:ok, operation}
      end
    catch
      :exit, _ -> {:error, :system_offline}
    end
  end
end