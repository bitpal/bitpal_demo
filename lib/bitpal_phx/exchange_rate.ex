defmodule BitPalPhx.ExchangeRate do
  @moduledoc false

  @type t :: %__MODULE__{
          rate: Decimal.t(),
          pair: {atom, atom}
        }

  defstruct [:rate, :pair]

  @spec new(Money.t(), Money.t()) :: t
  def new(amount, fiat_amount) do
    %__MODULE__{
      rate: Decimal.div(Money.to_decimal(fiat_amount), Money.to_decimal(amount)),
      pair: {amount.currency, fiat_amount.currency}
    }
  end

  @spec cast(map) :: {:ok, t} | {:error, :bad_pair} | :error
  def cast(%{"rate" => rate, "pair" => pair}) do
    with {:ok, pair} <- parse_pair(pair),
         {rate, ""} <- parse_rate(rate) do
      {:ok, %__MODULE__{pair: pair, rate: rate}}
    else
      err -> err
    end
  end

  defp parse_rate(rate) do
    Decimal.parse(rate)
  end

  defp parse_pair(pair) do
    case String.split(pair, "-") do
      [from, to] ->
        {:ok, {from, to}}

      _ ->
        {:error, :bad_pair}
    end
  end
end

defmodule BitPalPhx.ExchangeRates do
  @moduledoc false
  alias BitPalPhx.Cache
  alias BitPalPhx.ExchangeRate
  alias BitPalPhx.ProcessRegistry
  alias BitPalPhx.Socket
  require Logger

  @spec historic_rate({atom, atom}) :: ExchangeRate.t() | nil
  def historic_rate(pair) do
    Cache.get(pair)
  end

  def request(pair = {from, to}) do
    topic = topic(pair)
    Socket.join(topic)
    {:ok, ref} = Socket.push(topic, "rate", %{from: from, to: to})

    Task.Supervisor.start_child(
      BitPalPhx.TaskSupervisor,
      __MODULE__,
      :await_request_task,
      [ref, pair, self()]
    )

    ref
  end

  def await_request_task(ref, pair, pid) do
    # Not needed?? Or what if we miss it with `handle_reply`?
    Registry.register(ProcessRegistry, ProcessRegistry.via_tuple(ref), pair)

    case await_request(ref, pair) do
      {:ok, rate} ->
        send(pid, {:exchange_rate, rate})
        {:ok, rate}

      x ->
        Logger.warn("failed exchange rate request #{inspect(x)}")
    end
  end

  def await_request(ref, pair) do
    with {:ok, rate} <- Socket.await(ref),
         {:ok, rate} <- ExchangeRate.cast(rate) do
      Cache.put(pair, rate)
      {:ok, rate}
    else
      x -> x
    end
  end

  def await_request!(ref, pair) do
    {:ok, rate} = await_request(ref, pair)
    rate
  end

  defp topic({from, to}) do
    "exchange_rate:#{from}-#{to}"
  end
end
