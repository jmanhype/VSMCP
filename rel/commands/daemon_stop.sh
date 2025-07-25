#!/bin/bash
# Stop VSMCP daemon

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

export VSMCP_PID_FILE=${VSMCP_PID_FILE:-$RELEASE_ROOT/tmp/vsmcp.pid}

echo "Stopping VSMCP daemon..."

# Try to stop via RPC first
if "$RELEASE_ROOT/bin/vsmcp" stop >/dev/null 2>&1; then
    echo "VSMCP daemon stopped gracefully"
    rm -f "$VSMCP_PID_FILE"
    exit 0
fi

# If RPC fails, use PID file
if [ -f "$VSMCP_PID_FILE" ]; then
    PID=$(cat "$VSMCP_PID_FILE")
    
    if kill -0 "$PID" 2>/dev/null; then
        echo "Sending TERM signal to PID $PID..."
        kill -TERM "$PID"
        
        # Wait for graceful shutdown
        for i in {1..30}; do
            if ! kill -0 "$PID" 2>/dev/null; then
                echo "VSMCP daemon stopped"
                rm -f "$VSMCP_PID_FILE"
                exit 0
            fi
            sleep 1
        done
        
        # Force kill if still running
        echo "Forcing shutdown..."
        kill -KILL "$PID" 2>/dev/null || true
        rm -f "$VSMCP_PID_FILE"
        echo "VSMCP daemon forcefully stopped"
        exit 0
    else
        echo "PID $PID is not running"
        rm -f "$VSMCP_PID_FILE"
    fi
else
    echo "No PID file found at: $VSMCP_PID_FILE"
fi

echo "VSMCP daemon is not running"
exit 0