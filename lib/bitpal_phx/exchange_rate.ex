defmodule BitPalPhx.ExchangeRate do
  @moduledoc false

  @type t :: %__MODULE__{
          rate: Decimal.t(),
          pair: {atom, atom}
        }

  defstruct [:rate, :pair]

  @spec new(Money, Money) :: t
  def new(amount, fiat_amount) do
    %__MODULE__{
      rate: Decimal.div(Money.to_decimal(fiat_amount), Money.to_decimal(amount)),
      pair: {amount.currency, fiat_amount.currency}
    }
  end
end

defmodule BitPalPhx.ExchangeRates do
  @moduledoc false
  use GenServer
  alias BitPalPhx.Channels
  alias BitPalPhx.ExchangeRate
  alias Phoenix.PubSub
  alias PhoenixClient.{Channel, Message}
  require Logger

  @pubsub Demo.PubSub

  def subscribe(pair) do
    PubSub.subscribe(@pubsub, topic(pair))
    GenServer.cast(__MODULE__, {:async_request, pair})
  end

  def unsubscribe(pair) do
    PubSub.unsubscribe(@pubsub, topic(pair))
  end

  def request(pair) do
    GenServer.call(__MODULE__, {:request, pair})
  end

  def request!(pair) do
    case request(pair) do
      {:ok, rate} -> rate
      {:error, _} -> raise RuntimeError, "no exchange rate"
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_info(%Message{event: "rate", payload: rate}, state) do
    case cast_exchange_rate(rate) do
      {:ok, rate = %ExchangeRate{pair: pair}} ->
        PubSub.broadcast(
          @pubsub,
          topic(pair),
          {:exchange_rate, rate}
        )

        {:noreply, state}

      _ ->
        Logger.warning("bad exchange rate: #{inspect(rate)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:async_request, pair = {from, to}}, state) do
    with {:ok, channel} <- Channels.join(topic(pair)),
         {:ok, _} <- Channel.push(channel, "async_request", %{from: from, to: to}) do
      {:noreply, state}
    else
      err ->
        Logger.error("error requesting async exchange rate: #{inspect(err)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_call({:request, pair = {from, to}}, _from, state) do
    with {:ok, channel} <- Channels.join(topic(pair)),
         {:ok, rate} <- Channel.push(channel, "request", %{from: from, to: to}),
         {:ok, rate} <- cast_exchange_rate(rate) do
      {:reply, {:ok, rate}, state}
    else
      err ->
        Logger.error("error requesting exchange rate: #{inspect(err)}")
        {:reply, {:error, err}, state}
    end
  end

  defp cast_exchange_rate(%{"rate" => rate, "pair" => pair}) do
    with {:ok, pair} <- parse_pair(pair),
         {rate, ""} <- parse_rate(rate) do
      {:ok, %ExchangeRate{pair: pair, rate: rate}}
    else
      err -> err
    end
  end

  defp topic({from, to}) do
    "exchange_rate:#{from}-#{to}"
  end

  defp parse_rate(rate) do
    Decimal.parse(rate)
  end

  defp parse_pair(pair) do
    case String.split(pair, "-") do
      [from, to] ->
        {:ok, {from, to}}

      _ ->
        :bad_pair
    end
  end
end
