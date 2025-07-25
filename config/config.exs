import Config

# Phoenix configuration
config :vsmcp, VsmcpWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: VsmcpWeb.ErrorHTML, json: VsmcpWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Vsmcp.PubSub,
  live_view: [signing_salt: "vsmcp_live_view_salt"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# VSMCP Configuration
config :vsmcp,
  ecto_repos: [Vsmcp.Repo],
  telegram_bot_token: System.get_env("TELEGRAM_BOT_TOKEN"),
  amqp_url: System.get_env("AMQP_URL") || "amqp://guest:guest@localhost",
  mcp_port: String.to_integer(System.get_env("MCP_PORT") || "3000")

# ExGram Configuration
config :ex_gram,
  token: System.get_env("TELEGRAM_BOT_TOKEN"),
  adapter: Vsmcp.Finch

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"