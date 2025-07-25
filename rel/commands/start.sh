#!/bin/bash
# Start VSMCP service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

export RELEASE_NODE=${RELEASE_NODE:-vsmcp@127.0.0.1}
export RELEASE_COOKIE=${RELEASE_COOKIE:-vsmcp_cookie}

echo "Starting VSMCP..."
"$RELEASE_ROOT/bin/vsmcp" start

# Wait for service to start
sleep 2

# Check if service is running
if "$RELEASE_ROOT/bin/vsmcp" ping >/dev/null 2>&1; then
    echo "VSMCP started successfully"
    exit 0
else
    echo "Failed to start VSMCP"
    exit 1
fi