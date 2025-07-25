# CRDT-based ContextStore for VSMCP

This module provides a comprehensive CRDT (Conflict-free Replicated Data Type) implementation for the Viable System Model's distributed state management needs.

## Architecture Overview

### Core Components

1. **CRDT Types** (`lib/vsmcp/crdt/types/`)
   - **G-Counter**: Grow-only counter for monotonic increments
   - **PN-Counter**: Positive-Negative counter supporting both increment and decrement
   - **OR-Set**: Observed-Remove Set with proper add/remove semantics
   - **LWW-Register**: Last-Write-Wins Register for single-value storage

2. **Causality Tracking** (`lib/vsmcp/crdt/hlc.ex`)
   - Hybrid Logical Clock implementation
   - Ensures causal consistency across distributed nodes
   - Combines physical timestamps with logical counters

3. **Synchronization** (`lib/vsmcp/crdt/sync/pubsub_sync.ex`)
   - Phoenix.PubSub-based delta propagation
   - Anti-entropy synchronization for eventual consistency
   - Automatic peer discovery and state reconciliation

4. **Storage** (`lib/vsmcp/crdt/storage/tiered_storage.ex`)
   - Three-tier storage hierarchy: Memory → ETS → DETS
   - Automatic promotion/demotion based on access patterns
   - Configurable thresholds and decay rates

5. **High-Level API** (`lib/vsmcp/crdt/context_store.ex`)
   - Unified interface for all CRDT operations
   - Automatic synchronization and persistence
   - Type-safe operations with proper error handling

## Usage Examples

### Basic Counter Operations

```elixir
# Create a grow-only counter
:ok = ContextStore.create(:page_views, :g_counter)

# Increment the counter
{:ok, 1} = ContextStore.increment(:page_views)
{:ok, 6} = ContextStore.increment(:page_views, 5)

# Get current value
{:ok, 6} = ContextStore.get(:page_views)
```

### Bidirectional Counter

```elixir
# Create a PN-counter for tracking balance
:ok = ContextStore.create(:account_balance, :pn_counter)

# Add credits
{:ok, 100} = ContextStore.increment(:account_balance, 100)

# Deduct debits
{:ok, 75} = ContextStore.decrement(:account_balance, 25)
```

### Set Operations

```elixir
# Create a set for active users
:ok = ContextStore.create(:active_users, :or_set)

# Add users
{:ok, _} = ContextStore.add(:active_users, "user123")
{:ok, _} = ContextStore.add(:active_users, "user456")

# Remove user
{:ok, _} = ContextStore.remove(:active_users, "user123")

# Check current set
{:ok, users} = ContextStore.get(:active_users)
# users = MapSet<["user456"]>
```

### Register for Configuration

```elixir
# Create a register for current configuration
:ok = ContextStore.create(:system_config, :lww_register)

# Set configuration
config = %{
  mode: :production,
  features: [:crdt, :amqp, :mcp],
  version: "1.0.0"
}
{:ok, _} = ContextStore.set(:system_config, config)

# Get current configuration
{:ok, ^config} = ContextStore.get(:system_config)
```

## VSM Integration Patterns

### System 1 - Operational Metrics

```elixir
# Each operational unit tracks its metrics
:ok = ContextStore.create(:unit1_processed, :g_counter)
:ok = ContextStore.create(:unit1_errors, :pn_counter)

# During operation
{:ok, _} = ContextStore.increment(:unit1_processed, batch_size)
{:ok, _} = ContextStore.increment(:unit1_errors) # Error occurred
{:ok, _} = ContextStore.decrement(:unit1_errors) # False positive
```

### System 2 - Coordination State

```elixir
# Track active operations across units
:ok = ContextStore.create(:active_operations, :or_set)

# Register operation
operation = {:unit1, :process_order, "order_123"}
{:ok, _} = ContextStore.add(:active_operations, operation)

# Complete operation
{:ok, _} = ContextStore.remove(:active_operations, operation)
```

### System 3 - Policy Management

```elixir
# Store current operational policy
:ok = ContextStore.create(:current_policy, :lww_register)

policy = %{
  resource_allocation: %{unit1: 0.4, unit2: 0.3, unit3: 0.3},
  priority_mode: :balanced
}
{:ok, _} = ContextStore.set(:current_policy, policy)
```

### System 4 - Strategic Planning

```elixir
# Track opportunities and threats
:ok = ContextStore.create(:opportunities, :or_set)
:ok = ContextStore.create(:market_trends, :lww_register)

# Add opportunity
opportunity = %{id: "opp_001", type: :expansion, potential: :high}
{:ok, _} = ContextStore.add(:opportunities, opportunity)

# Update trends
{:ok, _} = ContextStore.set(:market_trends, %{growth: 0.15})
```

### System 5 - Identity Elements

```elixir
# Core values and objectives
:ok = ContextStore.create(:core_values, :or_set)
:ok = ContextStore.create(:mission_statement, :lww_register)

{:ok, _} = ContextStore.add(:core_values, :sustainability)
{:ok, _} = ContextStore.add(:core_values, :innovation)
{:ok, _} = ContextStore.set(:mission_statement, "Our mission...")
```

## Distributed Operation

The CRDT implementation automatically handles:

1. **Delta Propagation**: Only changes are transmitted, not full state
2. **Conflict Resolution**: Automatic merging based on CRDT semantics
3. **Eventual Consistency**: All nodes converge to the same state
4. **Partition Tolerance**: Continues operating during network splits
5. **Causality Preservation**: Operations maintain their causal relationships

## Performance Characteristics

- **Memory Tier**: Sub-microsecond access for hot data
- **ETS Tier**: Microsecond access for warm data
- **DETS Tier**: Millisecond access for cold data
- **Auto-promotion**: Frequently accessed data moves to faster tiers
- **Decay**: Unused data gradually moves to slower tiers

## Configuration

The CRDT subsystem is automatically started by the application supervisor. Custom configuration can be provided:

```elixir
# In config/config.exs
config :vsmcp, Vsmcp.CRDT.ContextStore,
  node_id: :custom_node_name,
  storage_opts: [
    memory_limit: 5000,      # Max items in memory
    ets_limit: 50_000,       # Max items in ETS
    access_threshold: 5,     # Promotions after N accesses
    decay_interval: 120_000  # 2 minute decay
  ]
```

## Testing

Comprehensive tests are provided in `test/vsmcp/crdt/context_store_test.exs`:

```bash
mix test test/vsmcp/crdt/context_store_test.exs
```

Tests cover:
- All CRDT type operations
- Convergence properties
- Storage tier transitions
- Error handling
- VSM integration patterns