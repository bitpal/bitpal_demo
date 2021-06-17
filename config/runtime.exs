import Config

case Config.config_env() do
  :dev ->
    :ok

  :test ->
    :ok

  :prod ->
    secret_key_base =
      System.get_env("SECRET_KEY_BASE") ||
        raise """
        environment variable SECRET_KEY_BASE is missing.
        You can generate one by calling: mix phx.gen.secret
        """

    config :demo, Demo.Endpoint,
      url: [host: "demo.bitpal.dev", port: 443],
      https: [
        port: 443,
        cipher_suite: :strong,
        keyfile: System.get_env("BITPAL_DEMO_SSL_KEY_PATH"),
        certfile: System.get_env("BITPAL_DEMO_SSL_CERT_PATH"),
        transport_options: [socket_opts: [:inet6]]
      ],
      check_origin: ["https://demo.bitpal.dev/"],
      secret_key_base: secret_key_base,
      force_ssl: [hsts: true]

    database_url =
      System.get_env("DATABASE_URL") ||
        raise """
        environment variable DATABASE_URL is missing.
        For example: ecto://USER:PASS@HOST/DATABASE
        """

    config :bitpal, BitPal.Repo,
      # ssl: true,
      url: database_url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

    # Configure Swoosh for mailing
    config :demo, Demo.Mailer,
      adapter: Swoosh.Adapters.SMTP,
      relay: "smtp.fastmail.com",
      username: System.get_env("BITPAL_EMAIL_USERNAME"),
      password: System.get_env("BITPAL_EMAIL_PASSWORD"),
      ssl: true,
      tls: :if_available,
      auth: :always,
      port: 465,
      retries: 2,
      no_mx_lookups: false
end
