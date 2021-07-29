defmodule Demo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children =
      [
        BitPalPhx.ProcessRegistry,
        {Task.Supervisor, name: BitPalPhx.TaskSupervisor},
        BitPalPhx.Cache,
        BitPalPhx.Invoices,
        Demo.Endpoint,
        {Phoenix.PubSub, name: Demo.PubSub}
      ] ++ socket()

    opts = [strategy: :one_for_one, name: Demo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp socket do
    # For testing we can turn off starting the socket
    if start_socket?() do
      [BitPalPhx.Socket]
    else
      []
    end
  end

  defp start_socket? do
    if settings = Application.get_env(:demo, BitPalPhx.Socket) do
      Keyword.get(settings, :start_link, true)
    else
      true
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Demo.Endpoint.config_change(changed, removed)
    :ok
  end
end
