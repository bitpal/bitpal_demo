defmodule Demo.MixProject do
  use Mix.Project

  def project do
    [
      app: :demo,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Demo.Application, []},
      extra_applications: [:logger, :runtime_tools, :swoosh, :gen_smtp]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      bitpal_dep(),
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:decimal, "~> 2.0"},
      {:floki, ">= 0.0.0"},
      {:gen_smtp, "~> 0.13"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:makeup, "~> 1.0.0"},
      {:makeup_elixir, "~> 0.14.0"},
      {:phoenix, "~> 1.5.9"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_inline_svg, "~> 1.4"},
      {:phoenix_live_dashboard, "~> 0.4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.15.0"},
      {:phoenix_swoosh, "~> 0.3"},
      {:plug_cowboy, "~> 2.4.1"},
      {:swoosh, "~> 1.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 0.4"}
    ]
  end

  defp bitpal_dep do
    case System.get_env("BITPAL_DEP") do
      nil ->
        {:bitpal, git: "https://github.com/bitpal/bitpal"}

      path ->
        {:bitpal, path: path}
    end
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      ci: ["demo.ci"],
      setup: ["deps.get", "cmd npm install --prefix assets", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
