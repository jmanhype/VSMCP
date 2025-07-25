import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :vsmcp, VsmcpWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "vsmcp_test_secret_key_base_at_least_64_bytes_long_for_security_reasons_test_only",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false