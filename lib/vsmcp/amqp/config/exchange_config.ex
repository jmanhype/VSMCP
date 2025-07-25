defmodule Vsmcp.AMQP.Config.ExchangeConfig do
  @moduledoc """
  Configuration for AMQP exchanges representing VSM nervous system channels.
  
  The VSM nervous system consists of:
  - Command Channel: System 1-2-3 vertical communication
  - Audit Channel: System 3 monitoring and compliance
  - Algedonic Channel: Emergency signals that bypass hierarchy
  - Horizontal Channel: Peer-to-peer communication between S1 units
  - Intel Channel: System 4 environmental scanning and future planning
  """

  @doc """
  Exchange definitions for VSM channels
  """
  def exchanges do
    %{
      command: %{
        name: "vsm.command",
        type: :topic,
        durable: true,
        auto_delete: false,
        internal: false,
        options: [
          arguments: [
            {"x-max-priority", :long, 10}
          ]
        ]
      },
      audit: %{
        name: "vsm.audit",
        type: :fanout,
        durable: true,
        auto_delete: false,
        internal: false,
        options: []
      },
      algedonic: %{
        name: "vsm.algedonic",
        type: :direct,
        durable: true,
        auto_delete: false,
        internal: false,
        options: [
          arguments: [
            {"x-max-priority", :long, 255},
            {"x-message-ttl", :long, 60000}  # 1 minute TTL for urgent signals
          ]
        ]
      },
      horizontal: %{
        name: "vsm.horizontal",
        type: :topic,
        durable: true,
        auto_delete: false,
        internal: false,
        options: []
      },
      intel: %{
        name: "vsm.intel",
        type: :topic,
        durable: true,
        auto_delete: false,
        internal: false,
        options: []
      }
    }
  end

  @doc """
  Queue definitions for each system
  """
  def queues do
    %{
      # System 1 operational queues
      system1: %{
        command: "vsm.system1.command",
        audit: "vsm.system1.audit",
        algedonic: "vsm.system1.algedonic",
        horizontal: "vsm.system1.horizontal",
        options: [durable: true, auto_delete: false]
      },
      # System 2 coordination queues
      system2: %{
        command: "vsm.system2.command",
        audit: "vsm.system2.audit",
        algedonic: "vsm.system2.algedonic",
        options: [durable: true, auto_delete: false]
      },
      # System 3 monitoring queues
      system3: %{
        command: "vsm.system3.command",
        audit: "vsm.system3.audit.all",  # Receives all audit messages
        algedonic: "vsm.system3.algedonic",
        options: [durable: true, auto_delete: false]
      },
      # System 4 intelligence queues
      system4: %{
        command: "vsm.system4.command",
        intel: "vsm.system4.intel",
        algedonic: "vsm.system4.algedonic",
        options: [durable: true, auto_delete: false]
      },
      # System 5 policy queues
      system5: %{
        command: "vsm.system5.command",
        algedonic: "vsm.system5.algedonic",
        intel: "vsm.system5.intel",
        options: [durable: true, auto_delete: false]
      }
    }
  end

  @doc """
  Routing key patterns for topic exchanges
  """
  def routing_patterns do
    %{
      command: %{
        # Command channel routing: system.level.action
        system1_all: "system1.*.*",
        system2_all: "system2.*.*",
        system3_all: "system3.*.*",
        system4_all: "system4.*.*",
        system5_all: "system5.*.*",
        operational: "*.operational.*",
        tactical: "*.tactical.*",
        strategic: "*.strategic.*"
      },
      horizontal: %{
        # Horizontal channel routing: unit.region.type
        all_units: "*.*.*",
        by_region: "*.#{:region}.*",
        by_type: "*.*.#{:type}"
      },
      intel: %{
        # Intelligence channel routing: source.type.urgency
        all_intel: "*.*.*",
        external: "external.*.*",
        internal: "internal.*.*",
        urgent: "*.*.urgent",
        routine: "*.*.routine"
      }
    }
  end

  @doc """
  Connection pool configuration
  """
  def connection_pool_config do
    %{
      size: 10,
      max_overflow: 5,
      strategy: :fifo,
      connection_opts: [
        host: System.get_env("RABBITMQ_HOST", "localhost"),
        port: String.to_integer(System.get_env("RABBITMQ_PORT", "5672")),
        username: System.get_env("RABBITMQ_USER", "guest"),
        password: System.get_env("RABBITMQ_PASS", "guest"),
        virtual_host: System.get_env("RABBITMQ_VHOST", "/"),
        heartbeat: 30,
        connection_timeout: 10_000
      ]
    }
  end

  @doc """
  Message priorities for different signal types
  """
  def message_priorities do
    %{
      algedonic: 255,      # Highest priority for pain/pleasure signals
      emergency: 200,      # Emergency operational issues
      command_urgent: 150, # Urgent commands
      audit_critical: 100, # Critical audit findings
      command_normal: 50,  # Normal commands
      intel_urgent: 75,    # Urgent intelligence
      intel_routine: 25,   # Routine intelligence
      horizontal: 10       # Peer communication (lowest)
    }
  end
end