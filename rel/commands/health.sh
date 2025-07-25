#!/bin/bash
# Health check for VSMCP service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Health check timeout
TIMEOUT=10

echo "VSMCP Health Check"
echo "=================="
echo ""

# Basic connectivity check
echo -n "1. Service Connectivity... "
if timeout "$TIMEOUT" "$RELEASE_ROOT/bin/vsmcp" ping >/dev/null 2>&1; then
    echo "✓ OK"
else
    echo "✗ FAILED"
    exit 1
fi

# Check all applications are running
echo -n "2. Application Health... "
APP_STATUS=$("$RELEASE_ROOT/bin/vsmcp" rpc "
  apps = Application.started_applications()
  required = [:vsmcp, :amqp, :phoenix_pubsub, :telemetry]
  missing = required -- (apps |> Enum.map(fn {app, _, _} -> app end))
  case missing do
    [] -> :ok
    apps -> {:error, apps}
  end
" 2>/dev/null || echo "error")

if [[ "$APP_STATUS" == "ok" ]]; then
    echo "✓ OK"
else
    echo "✗ FAILED (Missing: $APP_STATUS)"
    HEALTH_FAILED=true
fi

# Check system resources
echo -n "3. System Resources... "
RESOURCE_CHECK=$("$RELEASE_ROOT/bin/vsmcp" rpc "
  %{
    memory: :erlang.memory(:total) / 1024 / 1024,
    processes: length(:erlang.processes()),
    ports: length(:erlang.ports()),
    atoms: :erlang.system_info(:atom_count)
  }
" 2>/dev/null || echo "error")

if [[ "$RESOURCE_CHECK" != "error" ]]; then
    echo "✓ OK"
    echo "   $RESOURCE_CHECK"
else
    echo "✗ FAILED"
    HEALTH_FAILED=true
fi

# Check message queue health
echo -n "4. Message Queues... "
QUEUE_CHECK=$("$RELEASE_ROOT/bin/vsmcp" rpc "
  processes = :erlang.processes()
  large_queues = processes
    |> Enum.filter(fn pid ->
      case Process.info(pid, :message_queue_len) do
        {:message_queue_len, len} -> len > 1000
        _ -> false
      end
    end)
    |> length()
  
  if large_queues > 0 do
    {:warning, large_queues}
  else
    :ok
  end
" 2>/dev/null || echo "error")

case "$QUEUE_CHECK" in
  "ok")
    echo "✓ OK"
    ;;
  *warning*)
    echo "⚠ WARNING (Large queues: $QUEUE_CHECK)"
    ;;
  *)
    echo "✗ FAILED"
    HEALTH_FAILED=true
    ;;
esac

# Check database connectivity
echo -n "5. Database Connection... "
DB_CHECK=$("$RELEASE_ROOT/bin/vsmcp" rpc "
  case Ecto.Adapters.SQL.query(Vsmcp.Repo, \"SELECT 1\", []) do
    {:ok, _} -> :ok
    {:error, reason} -> {:error, inspect(reason)}
  end
" 2>/dev/null || echo "not_configured")

case "$DB_CHECK" in
  "ok")
    echo "✓ OK"
    ;;
  "not_configured")
    echo "○ Not Configured"
    ;;
  *)
    echo "✗ FAILED ($DB_CHECK)"
    HEALTH_FAILED=true
    ;;
esac

# Check AMQP connection
echo -n "6. AMQP Connection... "
AMQP_CHECK=$("$RELEASE_ROOT/bin/vsmcp" rpc "
  case Process.whereis(Vsmcp.AMQP.Connection) do
    nil -> :not_running
    pid when is_pid(pid) -> 
      if Process.alive?(pid), do: :ok, else: :dead
  end
" 2>/dev/null || echo "error")

case "$AMQP_CHECK" in
  "ok")
    echo "✓ OK"
    ;;
  "not_running")
    echo "○ Not Running"
    ;;
  *)
    echo "✗ FAILED"
    HEALTH_FAILED=true
    ;;
esac

# Overall health status
echo ""
echo "Overall Health Status: "
if [[ -z "$HEALTH_FAILED" ]]; then
    echo "✓ HEALTHY"
    exit 0
else
    echo "✗ UNHEALTHY"
    exit 1
fi