# VSMCP

Elixir implementation of Stafford Beer's Viable System Model (VSM) with MCP integration, AMQP messaging, and CRDT-based distributed state.

## Status

Early-stage (v0.1.0). Core supervision tree runs. No hex.pm release exists despite badge placeholders in the previous README. The CI badge pointed to a `viable-systems` org that does not match this repo's owner. Test coverage is unknown.

## What It Does

Maps Beer's 5 VSM subsystems onto an OTP application:

| VSM System | Role | Elixir Module |
|---|---|---|
| System 1 (Operations) | Autonomous work units, MCP tool execution | `Vsmcp.Systems.System1` |
| System 2 (Coordination) | Conflict resolution, anti-oscillation | `Vsmcp.Systems.System2` |
| System 3 (Control) | Resource allocation, audit channel (3*) | `Vsmcp.Systems.System3` |
| System 4 (Intelligence) | Environment scanning, MCP server discovery | `Vsmcp.Systems.System4` |
| System 5 (Policy) | Identity, governance, goal alignment | `Vsmcp.Systems.System5` |

Additional subsystems:

| Component | Purpose |
|---|---|
| AMQP Nervous System | RabbitMQ message routing between VSM layers |
| CRDT Store | Conflict-free replicated data types (OR-Set, G-Counter, LWW-Register, HLC) |
| MCP Server/Client | Model Context Protocol for dynamic tool discovery |
| Consciousness Interface | Meta-cognitive reflection layer |
| Variety Calculator | Ashby's Law of Requisite Variety metrics |

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Elixir 1.17+ / OTP 26+ |
| Messaging | RabbitMQ 3.13+ (AMQP) |
| State | CRDT (custom), optional PostgreSQL 14+ |
| Protocol | MCP (TCP, WebSocket, stdio transports) |
| Deployment | Docker, Kubernetes (manifests in `k8s/`) |
| Telemetry | OpenTelemetry-compatible, Prometheus on port 9568 |

## Project Layout

```
lib/vsmcp/
  systems/          # System 1-5 implementations
  amqp/             # Connection pool, channel manager, consumers, producers
  crdt/             # OR-Set, G-Counter, LWW-Register, HLC, storage
  mcp/              # Server, client, protocol, capability/tool registries
  consciousness/    # Meta-cognitive interface
  core/             # Variety calculator
config/             # dev.exs, runtime.exs, test.exs
k8s/                # Kubernetes base + production overlay
examples/           # Demo scripts (AMQP, Hermes MCP, Telegram VSM)
```

## Setup

```bash
git clone https://github.com/jmanhype/VSMCP.git
cd VSMCP
mix deps.get && mix compile
mix test
iex -S mix
```

Docker:

```bash
docker build -t vsmcp .
docker run -p 4010:4010 vsmcp
```

Kubernetes:

```bash
kubectl apply -f k8s/base/
```

## Configuration

Key environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `VSMCP_MCP_PORT` | 4010 | MCP server port |
| `VSMCP_MCP_TRANSPORT` | tcp | tcp, websocket, or stdio |
| `VSMCP_AMQP_URL` | amqp://localhost:5672 | RabbitMQ connection |
| `VSMCP_AMQP_POOL_SIZE` | 10 | Connection pool size |
| `VSMCP_METRICS_PORT` | 9568 | Prometheus metrics |
| `VSMCP_LOG_LEVEL` | info | debug, info, warn, error |

See `config/config.exs` for full tuning parameters (variety check intervals, recursion depth, prefetch counts, timeouts).

## Limitations

- No published hex package. The old README badges were aspirational.
- Telegram bot integration exists in `examples/` but the polling system had known issues (see `TELEGRAM_POLLING_INVESTIGATION_REPORT.md`).
- The "consciousness interface" is a structural placeholder, not an AI cognition system.
- CRDT implementation is custom and not benchmarked against established libraries like Delta-CRDT.
- No integration tests for the full AMQP nervous system path.

## License

See `LICENSE.md`.
