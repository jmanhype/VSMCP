# Production configuration example for VSMCP
import Config

# Core system configuration
config :vsmcp,
  # Distributed Erlang settings
  distributed: true,
  sync_nodes_mandatory: [],
  sync_nodes_optional: [],
  sync_nodes_timeout: 5000,
  
  # Variety management settings
  variety_check_interval: 30_000,      # Check every 30 seconds in production
  variety_threshold: 0.9,              # Higher threshold for production
  variety_alert_threshold: 0.95,       # Critical alert threshold
  
  # System recursion configuration
  recursion_depth: 5,                  # Deeper recursion for complex systems
  max_system1_units: 100,              # Maximum operational units
  
  # Performance tuning
  max_concurrent_operations: 10_000,   # High concurrency for production
  operation_timeout: 30_000,           # 30 second timeout
  coordination_timeout: 5_000,         # 5 second coordination timeout
  decision_timeout: 15_000,            # 15 second decision timeout
  
  # MCP configuration
  mcp_discovery_interval: 300_000,     # Discover new servers every 5 minutes
  mcp_capability_cache_ttl: 3_600_000, # Cache capabilities for 1 hour
  mcp_connection_timeout: 10_000,      # 10 second connection timeout
  mcp_request_timeout: 30_000,         # 30 second request timeout
  
  # Security settings
  allowed_mcp_servers: [
    "github.com/anthropic/*",
    "github.com/verified-mcp/*",
    "internal.company.com/*"
  ],
  enable_audit_log: true,
  audit_retention_days: 90,
  max_audit_log_size: 1_073_741_824,   # 1GB
  
  # Telemetry configuration
  telemetry_flush_interval: 10_000,    # Flush metrics every 10 seconds
  telemetry_buffer_size: 1000,         # Buffer up to 1000 events

# Phoenix PubSub configuration
config :vsmcp, Vsmcp.PubSub,
  name: Vsmcp.PubSub,
  adapter: Phoenix.PubSub.PG2,
  pool_size: 10

# MCP Server configuration
config :vsmcp, Vsmcp.MCP.Server,
  port: System.get_env("VSMCP_MCP_PORT", "4010") |> String.to_integer(),
  transport: System.get_env("VSMCP_MCP_TRANSPORT", "tcp"),
  max_connections: 1000,
  connection_timeout: 60_000,
  ssl: [
    certfile: System.get_env("SSL_CERT_PATH"),
    keyfile: System.get_env("SSL_KEY_PATH"),
    cacertfile: System.get_env("SSL_CA_PATH"),
    verify: :verify_peer,
    fail_if_no_peer_cert: true
  ]

# AMQP configuration
config :vsmcp, Vsmcp.AMQP,
  url: System.get_env("VSMCP_AMQP_URL"),
  pool_size: System.get_env("VSMCP_AMQP_POOL_SIZE", "20") |> String.to_integer(),
  max_overflow: 10,
  prefetch_count: 50,
  heartbeat: 30,
  connection_timeout: 10_000,
  reconnect_interval: 5_000,
  queue_options: [
    durable: true,
    auto_delete: false,
    arguments: [
      {"x-message-ttl", :long, 86_400_000},  # 24 hour TTL
      {"x-max-length", :long, 1_000_000}     # Max 1M messages
    ]
  ],
  exchange_options: [
    durable: true,
    auto_delete: false
  ]

# Database configuration
config :vsmcp, Vsmcp.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: System.get_env("DB_POOL_SIZE", "20") |> String.to_integer(),
  queue_target: 5_000,
  queue_interval: 10_000,
  migration_primary_key: [type: :uuid],
  migration_timestamps: [type: :utc_datetime_usec],
  ssl: true,
  ssl_opts: [
    verify: :verify_peer,
    cacertfile: System.get_env("DB_CA_CERT_PATH"),
    server_name_indication: System.get_env("DB_HOST") |> String.to_charlist()
  ]

# CRDT configuration
config :vsmcp, Vsmcp.CRDT,
  sync_interval: 5_000,                # Sync every 5 seconds
  conflict_resolution: :lww,           # Last-write-wins
  compression: :zstd,                  # Use Zstandard compression
  persistence: true,
  persistence_path: "/data/crdt",
  max_history: 1000                    # Keep last 1000 versions

# Security configuration
config :vsmcp, Vsmcp.Security,
  neural_bloom_filter: [
    size: 10_000_000,                  # 10M bit filter
    hash_functions: 7,                 # 7 hash functions
    false_positive_rate: 0.001,        # 0.1% false positive rate
    learning_rate: 0.1,                # Neural adaptation rate
    decay_factor: 0.995                # Slow decay for stability
  ],
  z3n_zones: [
    prod: [
      access_level: :restricted,
      audit: true,
      encryption: :aes256
    ],
    staging: [
      access_level: :limited,
      audit: true,
      encryption: :aes128
    ],
    dev: [
      access_level: :open,
      audit: false,
      encryption: nil
    ]
  ]

# Logger configuration
config :logger,
  level: :info,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [:request_id, :trace_id, :span_id, :system],
  backends: [
    :console,
    {LoggerFileBackend, :error_log},
    {LoggerFileBackend, :access_log}
  ]

config :logger, :console,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [:request_id, :trace_id, :span_id]

config :logger, :error_log,
  path: "/var/log/vsmcp/error.log",
  level: :error,
  format: "$date $time [$level] $metadata$message\n",
  metadata: :all,
  rotate: %{max_bytes: 104_857_600, keep: 10}  # 100MB files, keep 10

config :logger, :access_log,
  path: "/var/log/vsmcp/access.log",
  level: :info,
  format: "$date $time $metadata$message\n",
  metadata: [:method, :path, :status, :duration],
  rotate: %{max_bytes: 104_857_600, keep: 10}

# Cluster configuration
config :libcluster,
  topologies: [
    vsmcp: [
      strategy: Cluster.Strategy.Kubernetes.DNS,
      config: [
        service: "vsmcp-headless",
        application_name: "vsmcp",
        kubernetes_namespace: "vsmcp-system",
        polling_interval: 10_000
      ]
    ]
  ]

# Release configuration
config :vsmcp, Vsmcp.Release,
  cookie: System.fetch_env!("RELEASE_COOKIE"),
  node: System.fetch_env!("RELEASE_NODE")

# Health check endpoints
config :vsmcp, VsmcpWeb.Endpoint,
  url: [host: System.get_env("HOSTNAME", "localhost")],
  http: [port: 9568],
  server: true,
  check_origin: false