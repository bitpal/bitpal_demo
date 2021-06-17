use Mix.Config

config :bitpal, backends: [{BitPal.BackendMock, auto: false}]
config :bitpal, BitPal.ExchangeRate, backends: [BitPal.ExchangeRateMock]

config :bitpal, BitPal.Repo,
  username: "postgres",
  password: "postgres",
  database: "bitpal_demo_test",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :demo, Demo.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn
