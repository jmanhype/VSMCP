#!/bin/bash
# Start VSMCP in daemon mode

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default configuration
export RELEASE_NODE=${RELEASE_NODE:-vsmcp@127.0.0.1}
export RELEASE_COOKIE=${RELEASE_COOKIE:-vsmcp_cookie}
export VSMCP_LOG_DIR=${VSMCP_LOG_DIR:-$RELEASE_ROOT/log}
export VSMCP_PID_FILE=${VSMCP_PID_FILE:-$RELEASE_ROOT/tmp/vsmcp.pid}

# Create necessary directories
mkdir -p "$VSMCP_LOG_DIR"
mkdir -p "$(dirname "$VSMCP_PID_FILE")"

echo "Starting VSMCP in daemon mode..."

# Start in daemon mode
"$RELEASE_ROOT/bin/vsmcp" daemon

# Wait a moment for the daemon to start
sleep 3

# Check if daemon started successfully
if "$RELEASE_ROOT/bin/vsmcp" ping >/dev/null 2>&1; then
    # Get the PID and save it
    PID=$("$RELEASE_ROOT/bin/vsmcp" rpc ":os.getpid() |> to_string()" 2>/dev/null | tr -d '"')
    echo "$PID" > "$VSMCP_PID_FILE"
    
    echo "VSMCP daemon started successfully"
    echo "  Node: $RELEASE_NODE"
    echo "  PID: $PID"
    echo "  PID file: $VSMCP_PID_FILE"
    echo "  Logs: $VSMCP_LOG_DIR"
    exit 0
else
    echo "Failed to start VSMCP daemon"
    echo "Check logs at: $VSMCP_LOG_DIR/vsmcp.log"
    exit 1
fi