#!/bin/bash
# Stop VSMCP service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Stopping VSMCP..."

# Try graceful shutdown first
if "$RELEASE_ROOT/bin/vsmcp" stop >/dev/null 2>&1; then
    echo "VSMCP stopped gracefully"
    exit 0
fi

# If graceful shutdown fails, try to find and kill the process
PID_FILE="$RELEASE_ROOT/tmp/vsmcp.pid"
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Forcing shutdown of PID $PID..."
        kill -TERM "$PID"
        sleep 5
        if kill -0 "$PID" 2>/dev/null; then
            kill -KILL "$PID"
        fi
        rm -f "$PID_FILE"
        echo "VSMCP stopped"
        exit 0
    fi
fi

echo "VSMCP is not running"
exit 0