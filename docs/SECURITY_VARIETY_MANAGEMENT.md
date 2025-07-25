# Security & Variety Management in VSMCP

This document describes the Z3N security architecture and autonomous variety management system implemented in VSMCP.

## Overview

The security and variety management system provides:

1. **Z3N Zone-based Security**: Hierarchical access control based on VSM principles
2. **Neural Bloom Filters**: Intelligent threat detection with machine learning
3. **Distributed Data Management**: Using Z3n.Mria wrapper for resilient data storage
4. **Autonomous Variety Management**: Self-organizing responses to environmental complexity

## Architecture Components

### 1. Z3N Zone Control (`Vsmcp.Security.Z3nZoneControl`)

Implements hierarchical zone-based access control aligned with VSM structure:

- **Public Zone** (Level 0): Basic read access
- **Operational Zone** (Level 1): Execute operations, read data
- **Management Zone** (Level 2): Write configurations, full operations
- **Environment Zone** (Level 3): Monitor and adapt to environment
- **Viability Zone** (Level 4): Full system control and delegation

Features:
- JWT tokens with zone claims
- Zone transition validation
- Hierarchical permission inheritance
- Time-based token expiration

Example usage:
```elixir
# Generate zone token
{:ok, token} = Z3nZoneControl.generate_zone_token("user123", [:operational, :management])

# Validate access
{:ok, :granted} = Z3nZoneControl.validate_access(token, :operational, :execute)

# Transition between zones
{:ok, new_token} = Z3nZoneControl.transition_zone(token, :operational, :management)
```

### 2. Neural Bloom Filter (`Vsmcp.Security.NeuralBloomFilter`)

Advanced threat detection combining Bloom filter efficiency with neural pattern recognition:

Features:
- Traditional Bloom filter for known threat patterns
- Neural network for pattern analysis and anomaly detection
- Adaptive learning from confirmed threats and false positives
- Multiple threat type detection (injection, overflow, DoS, etc.)

Key capabilities:
- SQL injection detection
- XSS pattern recognition
- Buffer overflow indicators
- DoS attack patterns
- Anomaly detection using Shannon entropy

Example usage:
```elixir
# Check for threats
{is_threat, confidence, threat_info} = NeuralBloomFilter.check_threat(user_input)

# Report confirmed threat for learning
NeuralBloomFilter.report_threat(malicious_data, :injection, true)

# Report false positive for adjustment
NeuralBloomFilter.report_threat(safe_data, :injection, false)
```

### 3. Z3n.Mria Wrapper (`Vsmcp.Z3n.MriaWrapper`)

Distributed table management with Mnesia/Riak Core principles:

Features:
- Consistent hashing for data distribution
- Configurable replication factor
- Multiple consistency levels (eventual, causal, strong)
- Automatic rebalancing on node changes
- Goldrush event integration

Predefined tables:
- `vsm_states`: System state tracking
- `variety_gaps`: Variety gap measurements
- `security_events`: Security event log
- `mcp_capabilities`: Installed MCP servers

Example usage:
```elixir
# Write with consistency level
MriaWrapper.write(:security_events, event_record, :strong)

# Read with eventual consistency
{:ok, record} = MriaWrapper.read(:vsm_states, key, :eventual)

# Distributed query
results = MriaWrapper.query(:variety_gaps, match_spec, limit: 100)
```

### 4. Autonomous Variety Manager (`Vsmcp.Variety.AutonomousManager`)

Self-organizing system for managing operational variety:

Features:
- Variety gap detection using Ashby's Law
- Shannon entropy calculation for system complexity
- Automatic MCP capability discovery
- Worker pool scaling based on variety needs
- Autonomous response to critical gaps

Key thresholds:
- Critical gap: >70% - Immediate action required
- High gap: >50% - Planned intervention
- High entropy: >4.5 - System adaptation needed

Example usage:
```elixir
# Check current variety gaps
{:ok, analysis} = AutonomousManager.check_variety_gaps()

# Discover capabilities for a category
{:ok, capabilities} = AutonomousManager.discover_capabilities(:data_processing)

# Install capability
{:ok, result} = AutonomousManager.install_capability("postgresql-mcp")

# Enable autonomous mode
AutonomousManager.enable_autonomous_mode(true)
```

## Integration Module

The `Vsmcp.Security.Integration` module provides a unified interface:

```elixir
# Authenticate and get zone token
{:ok, token} = Integration.authenticate("user", [:operational], credentials)

# Perform secure operation
{:ok, result} = Integration.secure_operation(token, :operational, :query, data)

# Get system status
status = Integration.system_status()

# Enable autonomous mode (requires viability zone)
{:ok, :enabled} = Integration.enable_autonomous_mode(viability_token)

# Install capability with security check
{:ok, _} = Integration.install_capability(mgmt_token, "new-mcp-server")
```

## Security Workflows

### Authentication Flow
1. User provides credentials
2. Neural Bloom Filter checks for threat patterns
3. Zone token generated with appropriate permissions
4. Token includes expiration and transition history

### Secure Operation Flow
1. Validate zone access for requested operation
2. Check operation data for threats
3. Execute operation if all checks pass
4. Log operation to distributed table
5. Update neural patterns based on outcome

### Variety Management Flow
1. Periodic variety gap calculation
2. Shannon entropy analysis for complexity
3. If gap exceeds threshold:
   - Discover relevant MCP capabilities
   - Score based on variety amplification
   - Install highest-scored capability
   - Scale worker pool if needed
4. Monitor and adapt continuously

## Configuration

### Environment Variables
```elixir
# Z3N Secret for JWT signing
config :vsmcp, :z3n_secret, System.get_env("Z3N_SECRET")

# Variety thresholds
config :vsmcp, :variety_thresholds, %{
  critical: 0.7,
  high: 0.5,
  entropy: 4.5
}

# Neural Bloom Filter parameters
config :vsmcp, :bloom_filter, %{
  size: 100_000,
  hash_functions: 7,
  learning_rate: 0.01
}
```

### Autonomous Mode Settings
```elixir
# Enable autonomous variety management
AutonomousManager.enable_autonomous_mode(true)

# Configure worker scaling
config :vsmcp, :worker_scaling, %{
  min_workers: 2,
  max_workers: 20,
  scale_factor: 1.5
}
```

## Best Practices

1. **Zone Management**
   - Grant minimal necessary zones
   - Use zone transitions for temporary elevation
   - Monitor zone violation events

2. **Threat Detection**
   - Report false positives to improve accuracy
   - Regularly review threat patterns
   - Monitor neural network accuracy metrics

3. **Variety Management**
   - Start with autonomous mode disabled
   - Monitor recommendations before enabling
   - Set appropriate thresholds for your environment
   - Review installed capabilities regularly

4. **Distributed Data**
   - Choose consistency level based on use case
   - Monitor node health and rebalancing
   - Use appropriate table types (ram/disc)

## Monitoring and Alerts

The system provides comprehensive monitoring through:

1. **Phoenix PubSub channels**:
   - `security_events`: Threat detections and violations
   - `variety_alerts`: Variety gap notifications
   - `management_alerts`: Critical system events

2. **Distributed event system**:
   - Z3n events for data operations
   - Goldrush integration for complex event processing

3. **Metrics and statistics**:
   - Bloom filter saturation and accuracy
   - Zone access patterns
   - Variety gap trends
   - Worker pool utilization

## Testing

Run the security integration tests:
```bash
mix test test/security_integration_test.exs
```

The test suite covers:
- Zone-based access control
- Threat detection accuracy
- Variety gap analysis
- Autonomous responses
- Integration workflows

## Future Enhancements

1. **Multi-factor Authentication**: Additional security layers for zone access
2. **Federated Zones**: Cross-system zone trust relationships
3. **Advanced ML Models**: Deep learning for threat detection
4. **Predictive Variety Management**: Anticipate variety gaps before they occur
5. **Quantum-resistant Cryptography**: Future-proof security algorithms