import Config

case Config.config_env() do
  :dev ->
    :ok

  :test ->
    :ok

  :prod ->
    secret_key_base =
      System.get_env("DEMO_SECRET_KEY_BASE") ||
        raise """
        environment variable DEMO_SECRET_KEY_BASE is missing.
        You can generate one by calling: mix phx.gen.secret
        """

    config :demo, Demo.Endpoint, secret_key_base: secret_key_base

    config :demo, Demo.Mailer,
      username: System.get_env("DEMO_EMAIL_USERNAME"),
      password: System.get_env("DEMO_EMAIL_PASSWORD")

    config :demo,
      # NOTE need to be able to config http, for local access
      access_token: System.get_env("DEMO_ACCESS_TOKEN"),
      server_uri: System.get_env("DEMO_SERVER_URI")
end
