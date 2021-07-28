import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :demo, Demo.Endpoint,
  http: [port: 4002],
  server: false

config :demo, Demo.Mailer, adapter: Swoosh.Adapters.Test

config :demo, BitPalPhx.Socket, start_link: false

config :demo,
  access_token: "test-token",
  rest_endpoint: "http://0.0.0.0:4001"

# Print only warnings and errors during test
config :logger, level: :warn
