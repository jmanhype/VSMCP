# VSMCP System Architecture

## Table of Contents

1. [Overview](#overview)
2. [Core Principles](#core-principles)
3. [System Components](#system-components)
4. [Communication Architecture](#communication-architecture)
5. [Data Flow](#data-flow)
6. [Supervision Tree](#supervision-tree)
7. [Integration Points](#integration-points)
8. [Security Architecture](#security-architecture)
9. [Performance Architecture](#performance-architecture)
10. [Deployment Architecture](#deployment-architecture)

## Overview

VSMCP implements Stafford Beer's Viable System Model as a distributed, fault-tolerant system using Elixir/OTP. The architecture follows cybernetic principles while leveraging modern distributed systems patterns.

## Core Principles

### 1. Recursive Structure
Every viable system contains and is contained by other viable systems. Our architecture reflects this through:
- Nested supervision trees
- Fractal organization patterns
- Recursive variety management

### 2. Requisite Variety (Ashby's Law)
Only variety can destroy variety. The system maintains variety balance through:
- Dynamic capability acquisition via MCP
- Adaptive resource allocation
- Real-time variety calculation

### 3. Autonomy with Coordination
Operational units maintain autonomy while coordinating through:
- System 2 anti-oscillation mechanisms
- Algedonic (pain/pleasure) signaling
- Distributed state management via CRDTs

## System Components

### System 1 - Operations
```
┌─────────────────────────────────────────────┐
│             System 1 Supervisor              │
│                                             │
│  ┌───────────┐  ┌───────────┐  ┌─────────┐ │
│  │   Unit A   │  │   Unit B   │  │  Unit C │ │
│  │           │  │           │  │         │ │
│  │ ┌───────┐ │  │ ┌───────┐ │  │┌───────┐│ │
│  │ │Worker1│ │  │ │Worker1│ │  ││Worker1││ │
│  │ │Worker2│ │  │ │Worker2│ │  ││Worker2││ │
│  │ │Worker3│ │  │ │Worker3│ │  ││Worker3││ │
│  │ └───────┘ │  │ └───────┘ │  │└───────┘│ │
│  └───────────┘  └───────────┘  └─────────┘ │
└─────────────────────────────────────────────┘
```

**Responsibilities:**
- Execute primary operations
- Manage local variety
- Report performance metrics
- Handle MCP tool invocations

**Key Modules:**
- `Vsmcp.Systems.System1` - Main operational logic
- `Vsmcp.Systems.System1.Unit` - Individual operational unit
- `Vsmcp.Systems.System1.Worker` - Task execution

### System 2 - Coordination
```
┌─────────────────────────────────────────────┐
│              System 2 Process                │
│                                             │
│  ┌─────────────────┐  ┌──────────────────┐ │
│  │Conflict Resolver│  │Schedule Coordinator│ │
│  └────────┬────────┘  └────────┬─────────┘ │
│           │                     │           │
│      ┌────▼──────────────────────▼────┐    │
│      │   Coordination Protocol Bus     │    │
│      └─────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

**Responsibilities:**
- Prevent oscillation between units
- Resolve resource conflicts
- Maintain operational harmony
- Coordinate schedules

**Key Modules:**
- `Vsmcp.Systems.System2` - Coordination engine
- `Vsmcp.Systems.System2.ConflictResolver` - Conflict resolution
- `Vsmcp.Systems.System2.Scheduler` - Resource scheduling

### System 3 - Control
```
┌─────────────────────────────────────────────┐
│           System 3 Supervisor                │
│                                             │
│  ┌──────────────┐  ┌───────────────────┐   │
│  │Resource Mgmt │  │Performance Monitor │   │
│  └──────┬───────┘  └────────┬──────────┘   │
│         │                    │              │
│  ┌──────▼────────────────────▼──────────┐  │
│  │        Control Dashboard             │  │
│  └──────────────┬───────────────────────┘  │
│                 │                           │
│  ┌──────────────▼───────────────────────┐  │
│  │      Audit Channel (3*)              │  │
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

**Responsibilities:**
- Allocate resources optimally
- Monitor operational performance
- Direct audit investigations (3*)
- Optimize system efficiency

**Key Modules:**
- `Vsmcp.Systems.System3` - Control logic
- `Vsmcp.Systems.System3.ResourceManager` - Resource allocation
- `Vsmcp.Systems.System3.AuditChannel` - Direct inspection

### System 4 - Intelligence
```
┌─────────────────────────────────────────────┐
│           System 4 Supervisor                │
│                                             │
│  ┌───────────────┐  ┌──────────────────┐   │
│  │ Env. Scanner  │  │  MCP Discovery   │   │
│  └───────┬───────┘  └────────┬─────────┘   │
│          │                    │             │
│  ┌───────▼────────────────────▼─────────┐  │
│  │      Intelligence Synthesis          │  │
│  └───────────────┬──────────────────────┘  │
│                  │                          │
│  ┌───────────────▼──────────────────────┐  │
│  │        Future Modeling               │  │
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

**Responsibilities:**
- Scan external environment
- Discover MCP capabilities
- Model future scenarios
- Identify opportunities/threats

**Key Modules:**
- `Vsmcp.Systems.System4` - Intelligence operations
- `Vsmcp.Systems.System4.Scanner` - Environmental scanning
- `Vsmcp.Systems.System4.MCPDiscovery` - Capability discovery

### System 5 - Policy
```
┌─────────────────────────────────────────────┐
│            System 5 Process                  │
│                                             │
│  ┌───────────────┐  ┌──────────────────┐   │
│  │ Policy Engine │  │Identity Maintainer│   │
│  └───────┬───────┘  └────────┬─────────┘   │
│          │                    │             │
│  ┌───────▼────────────────────▼─────────┐  │
│  │      Strategic Decision Core         │  │
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

**Responsibilities:**
- Set organizational policy
- Maintain system identity
- Make strategic decisions
- Balance 3-4 interactions

**Key Modules:**
- `Vsmcp.Systems.System5` - Policy and governance
- `Vsmcp.Systems.System5.PolicyEngine` - Policy enforcement
- `Vsmcp.Systems.System5.IdentityManager` - Identity maintenance

## Communication Architecture

### 1. Phoenix PubSub
Primary communication backbone for inter-system messages:

```elixir
# Topic structure
"system:1:unit:A"      # System 1 unit topics
"system:2:coord"       # System 2 coordination
"system:3:control"     # System 3 control
"system:4:intel"       # System 4 intelligence
"system:5:policy"      # System 5 policy
"algedonic:alert"      # Pain/pleasure signals
```

### 2. AMQP Nervous System
High-throughput message routing for operational data:

```
Exchange Topology:
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Direct Ex. │     │  Topic Ex.  │     │ Fanout Ex.  │
│             │     │             │     │             │
│ Operations  │     │ Monitoring  │     │  Alerts     │
└─────────────┘     └─────────────┘     └─────────────┘
      │                   │                    │
      ▼                   ▼                    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Queue 1   │     │   Queue 2   │     │   Queue 3   │
└─────────────┘     └─────────────┘     └─────────────┘
```

### 3. MCP Communication
Model Context Protocol for capability acquisition:

```
Client ←→ TCP/WebSocket ←→ MCP Server Manager
   ↓                            ↓
Tool Invocation          Capability Registry
   ↓                            ↓
System 1 Units          System 4 Intelligence
```

## Data Flow

### Vertical Command Flow (Top-Down)
```
System 5 (Policy)
    │
    ├─> High-level directives
    │
    ▼
System 3 (Control)
    │
    ├─> Resource allocation
    ├─> Performance targets
    │
    ▼
System 1 (Operations)
    │
    └─> Execution
```

### Vertical Feedback Flow (Bottom-Up)
```
System 1 (Operations)
    │
    ├─> Performance data
    ├─> Variety metrics
    │
    ▼
System 3 (Control)
    │
    ├─> Aggregated reports
    ├─> Exception alerts
    │
    ▼
System 5 (Policy)
    │
    └─> Strategic adjustment
```

### Horizontal Information Flow
```
System 4 (Intelligence) ←→ System 5 (Policy)
         │                        │
         ├─> Environmental data   │
         ├─> Future models        │
         │                        │
         ▼                        ▼
    System 3 (Control) ←─────────┘
         │
         └─> Adaptive responses
```

### Algedonic Channel
```
Any System ──[PAIN/PLEASURE]──> System 5
                                    │
                                    ▼
                            Immediate Response
```

## Supervision Tree

### Root Supervisor Strategy
```elixir
defmodule Vsmcp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Core infrastructure
      {Telemetry.Supervisor, name: Vsmcp.Telemetry},
      {Phoenix.PubSub, name: Vsmcp.PubSub},
      
      # Core systems
      {Vsmcp.Supervisors.CoreSupervisor, []},
      
      # VSM Systems (order matters)
      {Vsmcp.Systems.System5, name: Vsmcp.Systems.System5},
      {Vsmcp.Systems.System4.Supervisor, []},
      {Vsmcp.Systems.System3.Supervisor, []},
      {Vsmcp.Systems.System2, name: Vsmcp.Systems.System2},
      {Vsmcp.Systems.System1.Supervisor, []},
      
      # Support systems
      {Vsmcp.Consciousness.Supervisor, []},
      {Vsmcp.MCP.Supervisor, []},
      
      # Optional systems
      {Vsmcp.AMQP.Supervisor, []},
      {Vsmcp.CRDT.Supervisor, []},
      {Vsmcp.Security.Supervisor, []}
    ]

    opts = [strategy: :one_for_one, name: Vsmcp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Supervision Strategies
- **one_for_one**: Default for independent processes
- **rest_for_one**: For dependent process chains
- **one_for_all**: For tightly coupled subsystems

### Restart Policies
```elixir
# Transient processes (only restart on abnormal exit)
restart: :transient  # MCP client connections

# Temporary processes (never restart)
restart: :temporary  # One-off calculations

# Permanent processes (always restart)
restart: :permanent  # Core VSM systems
```

## Integration Points

### 1. MCP Integration
```
┌─────────────────┐     ┌──────────────────┐
│   MCP Client    │────▶│  MCP Protocol    │
└─────────────────┘     └──────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌──────────────────┐
│ Tool Registry   │     │ Capability Cache │
└─────────────────┘     └──────────────────┘
         │                       │
         └───────────┬───────────┘
                     ▼
              ┌──────────────┐
              │  System 1    │
              │  Execution   │
              └──────────────┘
```

### 2. External APIs
- RESTful endpoints for monitoring
- GraphQL for complex queries (planned)
- WebSocket for real-time updates
- Prometheus metrics endpoint

### 3. Database Integration
- PostgreSQL for persistent state
- Redis for caching (optional)
- SQLite for edge deployments

## Security Architecture

### Zone-Based Security (Z3n)
```
┌─────────────────────────────────────────┐
│           Global Zone (Z0)               │
│  ┌───────────────────────────────────┐  │
│  │      Production Zone (Z1)         │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │   Operational Zone (Z2)     │  │  │
│  │  │  ┌───────────────────────┐  │  │  │
│  │  │  │  Restricted Zone (Z3) │  │  │  │
│  │  │  └───────────────────────┘  │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### Neural Bloom Filters
- Probabilistic anomaly detection
- Adaptive learning from patterns
- Low false-positive rate
- Memory-efficient implementation

### MCP Security
- Server allowlisting
- Capability verification
- Sandboxed execution
- Audit logging

## Performance Architecture

### Concurrency Model
```
1. Process per operational unit (System 1)
2. Dedicated processes for each VSM system
3. Worker pools for CPU-intensive tasks
4. Async I/O for external communications
```

### Performance Optimizations
1. **ETS Tables**: Fast in-memory lookups
2. **Process Pooling**: Reusable worker processes
3. **Binary References**: Efficient message passing
4. **Lazy Evaluation**: Deferred computations
5. **Circuit Breakers**: Prevent cascade failures

### Benchmarking Points
```elixir
# Telemetry events for performance monitoring
[:vsmcp, :variety, :calculation]
[:vsmcp, :system1, :operation]
[:vsmcp, :mcp, :tool_invocation]
[:vsmcp, :decision, :latency]
```

## Deployment Architecture

### Single Node Deployment
```
┌─────────────────────────┐
│      Load Balancer      │
└────────────┬────────────┘
             │
┌────────────▼────────────┐
│      VSMCP Node         │
│  ┌──────────────────┐   │
│  │   Beam VM        │   │
│  │  ┌────────────┐  │   │
│  │  │ VSMCP App  │  │   │
│  │  └────────────┘  │   │
│  └──────────────────┘   │
└─────────────────────────┘
```

### Distributed Deployment
```
┌─────────────────────────┐
│      Load Balancer      │
└──┬──────────┬────────┬──┘
   │          │        │
┌──▼───┐  ┌──▼───┐  ┌─▼───┐
│Node 1│  │Node 2│  │Node 3│
└──┬───┘  └──┬───┘  └─┬───┘
   │          │        │
   └──────────┴────────┘
        Distributed
         Erlang Mesh
```

### Kubernetes Architecture
```yaml
Namespace: vsmcp-system
├── Deployment: vsmcp (3 replicas)
├── Service: vsmcp-mcp (LoadBalancer)
├── Service: vsmcp-metrics (ClusterIP)
├── ConfigMap: vsmcp-config
├── Secret: vsmcp-secrets
├── PersistentVolumeClaim: vsmcp-data
└── HorizontalPodAutoscaler: vsmcp-hpa
```

## Monitoring and Observability

### Metrics Collection
```
Prometheus Scrape ──> Metrics Endpoint (:9568/metrics)
                           │
                           ▼
                    Telemetry.Metrics
                           │
                           ▼
                    System Telemetry Events
```

### Distributed Tracing
```
Request ──> Trace Context ──> Span Creation
              │                    │
              ▼                    ▼
         Propagation          Span Events
              │                    │
              └────────┬───────────┘
                       ▼
                 Trace Collector
```

### Log Aggregation
```
Application Logs ──> stdout/stderr ──> Container Runtime
                                            │
                                            ▼
                                      Log Aggregator
                                      (ELK/Loki/etc)
```

## Error Handling and Recovery

### Supervision Tree Recovery
1. Process crashes are isolated
2. Supervisor restarts failed processes
3. State is recovered from checkpoints
4. System continues operating

### Circuit Breaker Pattern
```elixir
External Service Call
        │
        ▼
┌─────────────────┐
│ Circuit Breaker │
├─────────────────┤
│ Closed → Open   │ (failures > threshold)
│ Open → Half-Open│ (after timeout)
│ Half-Open → *   │ (based on probe)
└─────────────────┘
```

### Graceful Degradation
1. Reduced functionality when components fail
2. Fallback to cached data
3. Synthetic responses for non-critical ops
4. Prioritization of essential services

## Future Architecture Considerations

### Planned Enhancements
1. **Event Sourcing**: Complete audit trail
2. **CQRS**: Separate read/write models  
3. **GraphQL Federation**: Microservices integration
4. **Service Mesh**: Enhanced observability
5. **Edge Computing**: Distributed intelligence

### Scalability Path
1. **Phase 1**: Single node optimization
2. **Phase 2**: Multi-node clustering
3. **Phase 3**: Geographic distribution
4. **Phase 4**: Edge deployment
5. **Phase 5**: Hybrid cloud/edge

## Conclusion

The VSMCP architecture embodies cybernetic principles while leveraging modern distributed systems patterns. The design ensures:

- **Viability**: Self-organizing and adaptive
- **Scalability**: Horizontal and vertical scaling
- **Reliability**: Fault-tolerant supervision
- **Extensibility**: Plugin architecture via MCP
- **Observability**: Comprehensive monitoring

This architecture provides a solid foundation for building autonomous, self-managing systems that can adapt to changing environments while maintaining operational efficiency.