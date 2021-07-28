defmodule BitPalPhx.SocketAPI do
  @moduledoc false
  @callback start_link(keyword) :: term
  @callback join(String.t()) :: :ok
  @callback push(String.t(), String.t(), map) :: {:ok, String.t()} | {:error, term}
  @callback await(String.t()) ::
              :ok
              | :error
              | {:ok, term}
              | {:error, term}
              | {:error, timeout}
end

defmodule BitPalPhx.Socket do
  @moduledoc false
  alias BitPalPhx.Invoices
  require Logger

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent
    }
  end

  @spec start_link(keyword) :: term
  def start_link(args), do: module().start_link(args)

  @spec join(String.t()) :: :ok
  def join(channel), do: module().join(channel)

  @spec push(String.t(), String.t(), map) :: {:ok, Slipstream.push_reference()} | {:error, term}
  def push(topic, event, params), do: module().push(topic, event, params)

  @spec await(Slipstream.push_reference()) ::
          :ok
          | :error
          | {:ok, term}
          | {:error, term}
          | {:error, timeout}
  def await(ref), do: module().await(ref)

  @spec handle_message(String.t(), String.t(), map) :: any
  def handle_message(topic, event, message) do
    case topic do
      "invoice" <> _ ->
        Invoices.handle_message(topic, event, message)

      _ ->
        Logger.warn("unknown message: #{topic} #{event} #{inspect(message)}")
    end
  end

  defp module do
    Application.get_env(:demo, :socket_client, BitPalPhx.SocketImpl)
  end
end

defmodule BitPalPhx.SocketImpl do
  @moduledoc false
  @behaviour BitPalPhx.SocketAPI
  use Slipstream, restart: :permanent
  require Logger

  @impl BitPalPhx.SocketAPI
  def start_link(args) do
    Slipstream.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl BitPalPhx.SocketAPI
  @spec join(String.t()) :: :ok
  def join(channel) do
    GenServer.cast(__MODULE__, {:join, channel})
  end

  @impl BitPalPhx.SocketAPI
  @spec push(String.t(), String.t(), map) :: {:ok, Slipstream.push_reference()} | {:error, term}
  def push(topic, event, params) do
    GenServer.call(__MODULE__, {:push, topic, event, params})
  end

  @impl BitPalPhx.SocketAPI
  @spec await(Slipstream.push_reference()) ::
          :ok
          | :error
          | {:ok, term}
          | {:error, term}
          | {:error, timeout}
  def await(ref) do
    GenServer.call(__MODULE__, {:await_reply, ref})
  end

  @impl Slipstream
  def init(_args) do
    config = Application.fetch_env!(:demo, __MODULE__)
    socket = new_socket() |> assign(:connect_config, config)
    {:ok, socket, {:continue, :connect}}
  end

  @impl Slipstream
  def handle_continue(:connect, socket) do
    config = socket.assigns.connect_config

    socket = connect!(socket, config)
    socket = await_connect!(socket)
    {:noreply, socket}
  end

  @impl Slipstream
  def handle_cast({:join, topic}, socket) do
    # While join doesn't mind, await_join will crash if we don't have this in place.
    if Slipstream.Socket.joined?(socket, topic) do
      {:noreply, socket}
    else
      socket =
        socket
        |> join(topic)
        |> await_join!(topic)

      {:noreply, socket}
    end
  end

  @impl Slipstream
  def handle_call({:push, topic, event, params}, _, socket) do
    {:reply, push(socket, topic, event, params), socket}
  end

  @impl Slipstream
  def handle_call({:await_reply, ref}, _, socket) do
    {:reply, await_reply(ref), socket}
  end

  @impl Slipstream
  def handle_message(topic, event, message, socket) do
    BitPalPhx.Socket.handle_message(topic, event, message)
    {:ok, socket}
  end

  @impl Slipstream
  def handle_reply(ref, message, socket) do
    Logger.warn("unhandled reply: #{ref} #{inspect(message)}")
    {:ok, socket}
  end
end
