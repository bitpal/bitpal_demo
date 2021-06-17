# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :bitpal,
  xpub:
    "xpub6DWyFPVAuvsno6PmiQq5Rrbw3Hb5fvD8EVSVGimu1koSuQc4HEmanCGVjc6GMxWpj2JsafJ4Rdbq2EwtprRxr6B9PxozpaoEDg6z168NYT1",
  recipent_description: "BitPal Demo",
  required_confirmations: 0

# Configures the endpoint
config :demo, Demo.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "5TKeJY+t76NIIJCFwLBu7yfjSI8DlN14H65sbN+AonRHFOBhBeSCSI1g4tmDlc7v",
  render_errors: [view: Demo.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Demo.PubSub,
  live_view: [signing_salt: "gI8eT+Yx"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :demo, :ecto_repos, [BitPal.Repo]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
