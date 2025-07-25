#!/bin/bash
set -e

# Default values
export RELEASE_NODE=${RELEASE_NODE:-vsmcp@$(hostname -i)}
export RELEASE_COOKIE=${RELEASE_COOKIE:-docker_vsmcp_cookie}
export VSMCP_LOG_LEVEL=${VSMCP_LOG_LEVEL:-info}

# Wait for dependencies
wait_for_service() {
    local host=$1
    local port=$2
    local service=$3
    
    echo "Waiting for $service at $host:$port..."
    
    for i in {1..30}; do
        if nc -z "$host" "$port" 2>/dev/null; then
            echo "$service is ready!"
            return 0
        fi
        sleep 2
    done
    
    echo "ERROR: $service failed to start"
    return 1
}

# Wait for required services if configured
if [ -n "$DATABASE_HOST" ]; then
    wait_for_service "$DATABASE_HOST" "${DATABASE_PORT:-5432}" "PostgreSQL"
fi

if [ -n "$AMQP_HOST" ]; then
    wait_for_service "$AMQP_HOST" "${AMQP_PORT:-5672}" "RabbitMQ"
fi

# Run migrations if enabled
if [ "$RUN_MIGRATIONS" = "true" ]; then
    echo "Running database migrations..."
    /opt/vsmcp/bin/vsmcp eval "Vsmcp.Release.migrate()"
fi

# Execute the main command
exec /opt/vsmcp/bin/vsmcp "$@"