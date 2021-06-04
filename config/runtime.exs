import Config

config :bitpal,
  xpub:
    "xpub6DWyFPVAuvsno6PmiQq5Rrbw3Hb5fvD8EVSVGimu1koSuQc4HEmanCGVjc6GMxWpj2JsafJ4Rdbq2EwtprRxr6B9PxozpaoEDg6z168NYT1",
  recipent_description: "BitPal Demo",
  required_confirmations: 5

case Config.config_env() do
  :dev ->
    # Mocking during development. If you want to test live replace it with a backend of your choice.
    config :bitpal, backends: [{BitPal.BackendMock, auto: true}]
    # config :bitpal, backends: [BitPal.Backend.Flowee]
    config :bitpal, BitPal.ExchangeRate, backends: [BitPal.ExchangeRateMock]

    config :bitpal, BitPal.Repo,
      username: "postgres",
      password: "postgres",
      database: "bitpal_demo_dev",
      hostname: "localhost",
      show_sensitive_data_on_connection_error: true,
      pool_size: 10

  :test ->
    config :bitpal,
      backends: [{BitPal.BackendMock, auto: false}]

    config :bitpal, BitPal.ExchangeRate, backends: [BitPal.ExchangeRateMock]

    config :bitpal, BitPal.Repo,
      username: "postgres",
      password: "postgres",
      database: "bitpal_demo_test",
      hostname: "localhost",
      show_sensitive_data_on_connection_error: true,
      pool: Ecto.Adapters.SQL.Sandbox

  :prod ->
    config :bitpal, backends: [BitPal.Backend.Flowee]
    config :bitpal, BitPal.ExchangeRate, backends: [BitPal.ExchangeRate.Kraken]

  _ ->
    :ok
end
