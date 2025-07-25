# VSM AMQP Nervous System

The AMQP nervous system implements the communication channels of the Viable System Model using RabbitMQ. It provides the critical information pathways that allow the five systems to coordinate and maintain viability.

## Architecture

### Channels (Exchanges)

1. **Command Channel** (`vsm.command` - Topic Exchange)
   - Vertical communication between systems
   - Hierarchical command flow (System 5 → 4 → 3 → 2 → 1)
   - Supports operational, tactical, and strategic routing

2. **Audit Channel** (`vsm.audit` - Fanout Exchange)
   - System 3 monitoring of all operations
   - All audit messages broadcast to monitoring systems
   - Compliance and performance tracking

3. **Algedonic Channel** (`vsm.algedonic` - Direct Exchange)
   - Emergency "pain/pleasure" signals
   - Bypasses hierarchy for urgent communication
   - Highest priority messages (255)
   - 1-minute TTL for time-critical signals

4. **Horizontal Channel** (`vsm.horizontal` - Topic Exchange)
   - Peer-to-peer communication between System 1 units
   - Load balancing and resource sharing
   - Regional coordination

5. **Intel Channel** (`vsm.intel` - Topic Exchange)
   - System 4 environmental scanning
   - Future planning and opportunity detection
   - Urgent and routine intelligence routing

### Components

```
lib/vsmcp/amqp/
├── README.md                    # This file
├── config/
│   └── exchange_config.ex       # Exchange and queue configuration
├── connection_pool.ex           # Connection pooling with auto-recovery
├── channel_manager.ex           # Channel lifecycle and setup
├── channel_monitor.ex           # Health monitoring and metrics
├── nervous_system.ex            # High-level API
├── supervisor.ex                # AMQP supervision tree
├── producers/
│   └── base_producer.ex         # Message publishing
└── consumers/
    ├── base_consumer.ex         # Consumer behaviour
    └── system3_consumer.ex      # Example: System 3 audit consumer
```

## Usage

### Basic Communication

```elixir
alias Vsmcp.AMQP.NervousSystem

# Send a command
NervousSystem.send_command(:system2, :system1, %{
  type: "resource_allocation",
  resources: %{cpu: 50, memory: 2048}
})

# Send audit data
NervousSystem.send_audit(:system1, %{
  metrics: %{
    throughput: 1000,
    error_rate: 0.01
  }
})

# Emergency signal
NervousSystem.send_algedonic(:system1, :system5, %{
  type: "resource_exhaustion",
  intensity: 200
})

# Horizontal coordination
NervousSystem.send_horizontal("unit_a", "region_1", "load_info", %{
  current_load: 75
})

# Intelligence data
NervousSystem.send_intel("scanner", "market", :urgent, %{
  opportunity: "ai_market",
  value: 1_000_000
})
```

### Monitoring

```elixir
# Get channel metrics
{:ok, metrics} = NervousSystem.get_metrics()

# Check channel health
{:ok, :healthy} = NervousSystem.get_channel_health(:command)
```

### Advanced Operations

```elixir
# Emergency broadcast to all systems
NervousSystem.emergency_broadcast(:system3, %{
  type: "security_breach",
  intensity: 255
})

# Coordinate resources across units
NervousSystem.coordinate_resources(:system2, [
  {"unit_a", %{available: 30}},
  {"unit_b", %{required: 40}}
])
```

## Message Routing

### Command Channel Routing

- Pattern: `system.level.action`
- Examples:
  - `system1.operational.execute`
  - `system3.tactical.audit`
  - `system5.strategic.policy`

### Horizontal Channel Routing

- Pattern: `unit.region.type`
- Examples:
  - `unit_a.region_1.load_info`
  - `unit_b.region_2.resource_request`

### Intel Channel Routing

- Pattern: `source.type.urgency`
- Examples:
  - `external.market.urgent`
  - `internal.performance.routine`

## Message Priorities

1. **Algedonic**: 255 (highest)
2. **Emergency**: 200
3. **Command Urgent**: 150
4. **Audit Critical**: 100
5. **Intel Urgent**: 75
6. **Command Normal**: 50
7. **Intel Routine**: 25
8. **Horizontal**: 10 (lowest)

## Connection Management

The system uses a connection pool with:
- 10 connections (5 overflow)
- Automatic reconnection on failure
- Health monitoring
- FIFO connection strategy

## Creating System Consumers

To create a consumer for a VSM system:

```elixir
defmodule Vsmcp.AMQP.Consumers.System1Consumer do
  use Vsmcp.AMQP.Consumers.BaseConsumer, system: :system1
  
  # Define which queues to subscribe to
  defp default_subscriptions do
    [
      "vsm.system1.command",
      "vsm.system1.audit",
      "vsm.system1.algedonic",
      "vsm.system1.horizontal"
    ]
  end
  
  # Handle different message types
  @impl true
  def handle_command(command, metadata) do
    # Process command
    :ok
  end
  
  @impl true
  def handle_algedonic(signal, metadata) do
    # React to emergency signal
    :ok
  end
end
```

## Configuration

Set RabbitMQ connection parameters via environment variables:

- `RABBITMQ_HOST` (default: "localhost")
- `RABBITMQ_PORT` (default: "5672")
- `RABBITMQ_USER` (default: "guest")
- `RABBITMQ_PASS` (default: "guest")
- `RABBITMQ_VHOST` (default: "/")

## Supervision

The AMQP nervous system is supervised with a `rest_for_one` strategy:

1. Connection Pool (foundational)
2. Channel Manager (depends on connections)
3. Channel Monitor (observes channels)
4. System Consumers (use channels)

If the connection pool fails, all dependent processes restart in order.

## Error Handling

- Automatic reconnection on connection loss
- Message requeuing on processing failure
- Channel monitoring and recovery
- Graceful degradation under load

## Metrics and Monitoring

The Channel Monitor tracks:
- Messages sent/received per channel
- Error rates and last errors
- Queue depths and consumer lag
- Overall system health
- Throughput calculations

Access metrics via:
```elixir
{:ok, metrics} = Vsmcp.AMQP.ChannelMonitor.get_metrics()
```