import Config

# Runtime configuration for VSMCP
# This file is executed at runtime and can read environment variables

if config_env() == :prod do
  # Production configurations
  
  # Phoenix Endpoint Configuration
  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :vsmcp, VsmcpWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: System.get_env("SECRET_KEY_BASE"),
    server: true

  # Telegram Bot Configuration
  config :vsmcp, :telegram,
    bot_token: System.get_env("TELEGRAM_BOT_TOKEN"),
    webhook_url: System.get_env("TELEGRAM_WEBHOOK_URL")
  
  # AMQP Configuration
  config :vsmcp, :amqp,
    host: System.get_env("RABBITMQ_HOST", "localhost"),
    port: String.to_integer(System.get_env("RABBITMQ_PORT", "5672")),
    username: System.get_env("RABBITMQ_USERNAME", "guest"),
    password: System.get_env("RABBITMQ_PASSWORD", "guest"),
    virtual_host: System.get_env("RABBITMQ_VHOST", "/")
  
  # MCP Server Configuration
  config :vsmcp, :mcp,
    server_port: String.to_integer(System.get_env("MCP_SERVER_PORT", "3000")),
    transport: String.to_atom(System.get_env("MCP_TRANSPORT", "stdio"))
end

# Development and test environments can use compile-time config
if config_env() in [:dev, :test] do
  # Telegram Bot Configuration (for development)
  config :vsmcp, :telegram,
    bot_token: System.get_env("TELEGRAM_BOT_TOKEN", "7747520054:AAFNts5iJn8mYZezAG9uQF2_slvuztEScZI"),
    webhook_url: nil
  
  # AMQP Configuration (for development)
  config :vsmcp, :amqp,
    host: "localhost",
    port: 5672,
    username: "guest",
    password: "guest",
    virtual_host: "/"
  
  # MCP Server Configuration (for development)
  config :vsmcp, :mcp,
    server_port: 3000,
    transport: :stdio
end