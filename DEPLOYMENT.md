# VSMCP Deployment Guide

This guide provides detailed instructions for deploying VSMCP in various environments.

## Table of Contents

1. [Local Development](#local-development)
2. [Docker Deployment](#docker-deployment)
3. [Kubernetes Deployment](#kubernetes-deployment)
4. [Production Deployment](#production-deployment)
5. [Configuration Management](#configuration-management)
6. [Monitoring and Observability](#monitoring-and-observability)
7. [Troubleshooting](#troubleshooting)

## Local Development

### Prerequisites

- Elixir 1.17+ with OTP 26+
- RabbitMQ 3.13+ (for AMQP features)
- PostgreSQL 14+ (optional, for persistent state)

### Quick Start

```bash
# Clone and setup
git clone https://github.com/viable-systems/vsmcp.git
cd vsmcp

# Install dependencies
mix deps.get
mix compile

# Start services (using Docker Compose)
docker-compose -f examples/config/docker-compose.yml up -d rabbitmq postgres

# Run the application
iex -S mix

# Or run with specific node name
iex --name vsmcp@localhost --cookie dev-cookie -S mix
```

### Development Configuration

Create a `config/dev.local.exs` file for local overrides:

```elixir
import Config

config :vsmcp,
  amqp_url: "amqp://guest:guest@localhost:5672",
  postgres_url: "postgresql://postgres:postgres@localhost:5432/vsmcp_dev"
```

## Docker Deployment

### Building the Image

```bash
# Build the Docker image
docker build -t vsmcp:latest .

# Build with specific version tag
docker build -t vsmcp:v0.1.0 .
```

### Running with Docker

```bash
# Run standalone
docker run -p 4010:4010 -p 9568:9568 vsmcp:latest

# Run with environment variables
docker run -p 4010:4010 -p 9568:9568 \
  -e VSMCP_NODE_NAME=vsmcp@docker \
  -e VSMCP_COOKIE=secure-cookie \
  -e VSMCP_AMQP_URL=amqp://rabbitmq:5672 \
  vsmcp:latest

# Run with persistent data
docker run -p 4010:4010 -p 9568:9568 \
  -v vsmcp-data:/app/data \
  vsmcp:latest
```

### Docker Compose

Use the provided `docker-compose.yml`:

```bash
cd examples/config
docker-compose up -d

# View logs
docker-compose logs -f vsmcp

# Scale the application
docker-compose up -d --scale vsmcp=3
```

## Kubernetes Deployment

### Prerequisites

- Kubernetes 1.28+
- kubectl configured
- Helm 3+ (optional)

### Basic Deployment

```bash
# Create namespace
kubectl create namespace vsmcp-system

# Apply configurations
kubectl apply -f examples/config/kubernetes.yaml

# Check deployment
kubectl get pods -n vsmcp-system
kubectl get services -n vsmcp-system
```

### Helm Chart (Optional)

```bash
# Add VSMCP Helm repository
helm repo add vsmcp https://charts.vsmcp.org
helm repo update

# Install with default values
helm install vsmcp vsmcp/vsmcp -n vsmcp-system --create-namespace

# Install with custom values
helm install vsmcp vsmcp/vsmcp -n vsmcp-system \
  --set replicas=5 \
  --set resources.requests.memory=1Gi \
  --set mcp.port=4010
```

### Accessing the Application

```bash
# Port forwarding for local access
kubectl port-forward -n vsmcp-system svc/vsmcp-mcp 4010:4010

# Get external IP (if using LoadBalancer)
kubectl get svc -n vsmcp-system vsmcp-mcp
```

## Production Deployment

### Infrastructure Requirements

#### Minimum Requirements
- 3 nodes for high availability
- 4 CPU cores per node
- 8GB RAM per node
- 50GB SSD storage per node
- 10Gbps network between nodes

#### Recommended Requirements
- 5+ nodes for better fault tolerance
- 8 CPU cores per node
- 16GB RAM per node
- 100GB SSD storage per node
- 25Gbps network between nodes

### Security Considerations

1. **Network Security**
   - Use TLS for all external communications
   - Configure firewalls to restrict access
   - Use private networks for inter-node communication

2. **Authentication & Authorization**
   - Enable MCP authentication
   - Use strong Erlang cookies
   - Implement RBAC for Kubernetes

3. **Data Security**
   - Encrypt data at rest
   - Use encrypted connections to databases
   - Regular security audits

### Production Configuration

Use the provided `production.exs` example:

```elixir
# config/prod.exs
import Config

config :vsmcp,
  distributed: true,
  sync_nodes_mandatory: [
    :"vsmcp@node1.example.com",
    :"vsmcp@node2.example.com",
    :"vsmcp@node3.example.com"
  ],
  variety_check_interval: 30_000,
  max_concurrent_operations: 10_000
```

### Deployment Steps

1. **Prepare Infrastructure**
   ```bash
   # Setup nodes
   ansible-playbook -i inventory setup-nodes.yml
   ```

2. **Deploy Database**
   ```bash
   # PostgreSQL cluster
   helm install postgresql bitnami/postgresql-ha \
     -n vsmcp-system \
     --set postgresql.replicaCount=3
   ```

3. **Deploy Message Queue**
   ```bash
   # RabbitMQ cluster
   helm install rabbitmq bitnami/rabbitmq \
     -n vsmcp-system \
     --set replicaCount=3 \
     --set clustering.enabled=true
   ```

4. **Deploy VSMCP**
   ```bash
   # Apply production manifests
   kubectl apply -f deployment/production/
   ```

5. **Configure Load Balancer**
   ```bash
   # Apply ingress rules
   kubectl apply -f deployment/ingress.yaml
   ```

## Configuration Management

### Environment Variables

See the README for a complete list of environment variables.

### Configuration Files

1. **Application Config** (`config/config.exs`)
   - Core application settings
   - System recursion levels
   - Variety thresholds

2. **Runtime Config** (`config/runtime.exs`)
   - Environment-specific settings
   - Database connections
   - External service URLs

3. **Release Config** (`config/releases.exs`)
   - Production release settings
   - Clustering configuration
   - Health check endpoints

### Dynamic Configuration

VSMCP supports runtime configuration updates:

```elixir
# Update variety threshold
Vsmcp.Config.update(:variety_threshold, 0.9)

# Update MCP allowed servers
Vsmcp.Config.update(:allowed_mcp_servers, ["github.com/verified/*"])
```

## Monitoring and Observability

### Metrics

VSMCP exposes Prometheus metrics on port 9568:

```bash
# View metrics
curl http://localhost:9568/metrics

# Key metrics to monitor
- vsmcp_variety_gap
- vsmcp_system_health
- vsmcp_mcp_requests_total
- vsmcp_decision_latency_seconds
```

### Logging

Configure log aggregation:

```yaml
# fluentd configuration
<source>
  @type tail
  path /var/log/vsmcp/*.log
  pos_file /var/log/td-agent/vsmcp.pos
  tag vsmcp.*
  <parse>
    @type json
  </parse>
</source>
```

### Distributed Tracing

Enable OpenTelemetry:

```elixir
config :opentelemetry,
  span_processor: :batch,
  exporter: :otlp,
  otlp_endpoint: "http://jaeger:4317"
```

### Dashboards

Import provided Grafana dashboards:

1. System Overview Dashboard
2. Variety Management Dashboard
3. MCP Operations Dashboard
4. Performance Metrics Dashboard

## Troubleshooting

### Common Issues

#### High Variety Gap

**Symptoms**: Variety gap alerts, degraded performance

**Solution**:
```elixir
# Check variety status
Vsmcp.diagnose_variety_gap()

# Add MCP capabilities
Vsmcp.MCP.discover_servers()
Vsmcp.MCP.acquire_capability("needed_tool")

# Scale operational units
Vsmcp.Systems.System1.scale_units(10)
```

#### Node Connectivity Issues

**Symptoms**: Nodes not forming cluster

**Solution**:
```bash
# Check node connectivity
epmd -names

# Verify cookie
cat ~/.erlang.cookie

# Test connection
erl -name test@node1 -setcookie $COOKIE -eval 'net_adm:ping(vsmcp@node2)'
```

#### Memory Issues

**Symptoms**: High memory usage, OOM errors

**Solution**:
```elixir
# Check memory usage
:erlang.memory()

# Force garbage collection
:erlang.garbage_collect()

# Adjust memory limits
System.put_env("ERL_MAX_ETS_TABLES", "10000")
```

### Debug Mode

Enable debug logging:

```elixir
# In config
config :logger, level: :debug

# At runtime
Logger.configure(level: :debug)

# For specific module
Logger.put_module_level(Vsmcp.Systems.System5, :debug)
```

### Health Checks

```bash
# Liveness check
curl http://localhost:9568/health

# Readiness check
curl http://localhost:9568/ready

# Detailed status
curl http://localhost:9568/status
```

## Backup and Recovery

### Data Backup

```bash
# Backup CRDT state
kubectl exec -n vsmcp-system vsmcp-0 -- \
  tar czf /tmp/crdt-backup.tar.gz /app/data/crdt

# Backup PostgreSQL
pg_dump -h localhost -U vsmcp vsmcp_prod > backup.sql
```

### Disaster Recovery

1. **Stop Applications**
   ```bash
   kubectl scale deployment vsmcp --replicas=0 -n vsmcp-system
   ```

2. **Restore Data**
   ```bash
   # Restore database
   psql -h localhost -U vsmcp vsmcp_prod < backup.sql
   
   # Restore CRDT state
   kubectl cp crdt-backup.tar.gz vsmcp-0:/tmp/
   kubectl exec vsmcp-0 -- tar xzf /tmp/crdt-backup.tar.gz -C /
   ```

3. **Start Applications**
   ```bash
   kubectl scale deployment vsmcp --replicas=3 -n vsmcp-system
   ```

## Performance Tuning

### Erlang VM Tuning

```bash
# Start with optimized flags
ERL_FLAGS="+P 5000000 +Q 1000000 +K true +A 128" mix start

# Scheduler tuning
+S 8:8  # 8 schedulers, 8 online
+sbt db # Bind schedulers to topology
```

### Application Tuning

```elixir
# Increase process limit
:erlang.system_flag(:max_processes, 5_000_000)

# Tune ETS tables
:ets.new(:cache, [:set, :public, {:read_concurrency, true}])
```

### Database Tuning

```sql
-- PostgreSQL settings
ALTER SYSTEM SET shared_buffers = '4GB';
ALTER SYSTEM SET effective_cache_size = '12GB';
ALTER SYSTEM SET max_connections = 200;
```

## Support

For deployment support:
- Documentation: https://docs.vsmcp.org
- Discord: https://discord.gg/vsmcp
- Issues: https://github.com/viable-systems/vsmcp/issues