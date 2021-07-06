defmodule BitPalPhx.ChannelsAPI do
  @moduledoc false
  @callback join(String.t(), non_neg_integer) :: {:ok, pid} | {:error, :timeout} | {:error, term}
end

defmodule BitPalPhx.Channels do
  @moduledoc false
  @behaviour BitPalPhx.ChannelsAPI
  alias PhoenixClient.Channel

  @spec join(String.t()) :: {:ok, pid} | {:error, :timeout} | {:error, term}
  def join(channel) do
    # Can be overridden by mock for tests
    channels = Application.get_env(:demo, :channels_client, __MODULE__)
    channels.join(channel, 50)
  end

  @impl true
  def join(_channel, tries) when tries <= 0 do
    {:error, :timeout}
  end

  def join(channel, tries) do
    case Channel.join(BitPalPhx.Socket, channel) do
      {:ok, _response, pid} ->
        {:ok, pid}

      {:error, :socket_not_connected} ->
        Process.sleep(100)
        join(channel, tries - 1)

      {:error, {:already_joined, pid}} ->
        {:ok, pid}

      err ->
        err
    end
  end
end

defmodule BitPalPhx.ChannelsMock do
  @moduledoc false
  @behaviour BitPalPhx.ChannelsAPI

  @impl true
  def join(_channel, _tries) do
    {:ok, pid} = BitPalPhx.ChannelMock.start_link([])
    {:ok, pid}
  end
end

defmodule BitPalPhx.ChannelMock do
  @moduledoc false
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:push, "async_request", _params}, _from, state) do
    {:reply, {:ok, :ok}, state}
  end

  @impl true
  def handle_call({:push, "request", %{from: from, to: to}}, _from, state) do
    {:reply, {:ok, %{"rate" => "1.337", "pair" => "#{from}-#{to}"}}, state}
  end
end
