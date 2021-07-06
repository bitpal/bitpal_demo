defmodule Demo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    socket_opts = [
      url: "ws://0.0.0.0:4001/socket/websocket"
    ]

    children = [
      {PhoenixClient.Socket, {socket_opts, name: BitPalPhx.Socket}},
      BitPalPhx.Cache,
      BitPalPhx.ExchangeRates,
      BitPalPhx.Invoices,
      Demo.Endpoint,
      {Phoenix.PubSub, name: Demo.PubSub}
    ]

    opts = [strategy: :one_for_one, name: Demo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Demo.Endpoint.config_change(changed, removed)
    :ok
  end
end
