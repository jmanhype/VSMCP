#!/bin/bash
# Check VSMCP service status

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Function to check if service is running
check_running() {
    "$RELEASE_ROOT/bin/vsmcp" ping >/dev/null 2>&1
}

# Function to get service info
get_info() {
    "$RELEASE_ROOT/bin/vsmcp" rpc "Vsmcp.CLI.status()"
}

echo "VSMCP Status Report"
echo "=================="

if check_running; then
    echo "Status: RUNNING ✓"
    echo ""
    
    # Get detailed status from the running system
    if STATUS_INFO=$(get_info 2>/dev/null); then
        echo "$STATUS_INFO"
    else
        echo "Node Information:"
        "$RELEASE_ROOT/bin/vsmcp" rpc "Node.self()"
        echo ""
        echo "Application Status:"
        "$RELEASE_ROOT/bin/vsmcp" rpc "Application.started_applications() |> Enum.map(fn {app, _, _} -> app end)"
    fi
else
    echo "Status: STOPPED ✗"
    
    # Check for PID file
    PID_FILE="$RELEASE_ROOT/tmp/vsmcp.pid"
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ! kill -0 "$PID" 2>/dev/null; then
            echo "Warning: Stale PID file found (PID: $PID)"
        fi
    fi
fi

echo ""
echo "Log files:"
echo "  - Application: $RELEASE_ROOT/log/vsmcp.log"
echo "  - Erlang: $RELEASE_ROOT/log/erlang.log"
echo "  - Crash dump: $RELEASE_ROOT/log/erl_crash.dump"

exit 0