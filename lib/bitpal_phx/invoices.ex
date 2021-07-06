defmodule BitPalPhx.Invoices do
  @moduledoc false
  use GenServer
  import Ecto.Changeset
  alias BitPalPhx.Channels
  alias BitPalPhx.Invoice
  alias BitPalPhx.Transaction
  alias Ecto.Changeset
  alias Phoenix.PubSub
  alias PhoenixClient.Message
  require Logger

  @pubsub Demo.PubSub

  # Requests

  @spec fetch(String.t()) :: {:ok, Invoice.t()} | {:error, Changeset.t()}
  def fetch(_key) do
    {:error, %Changeset{}}
  end

  @spec create(
          %{
            amount: Money.t(),
            exchange_rate: %{rate: Decimal.t(), pair: {atom, atom}},
            finalize: boolean
          },
          keyword
        ) :: {:ok, Invoice.t()} | {:error, Changeset.t()}
  def create(
        %{
          amount: amount,
          exchange_rate: %{rate: rate, pair: {currency, fiat_currency}}
        },
        opts \\ []
      ) do
    finalize = Keyword.get(opts, :finalize, false)

    http = Application.get_env(:demo, :http_client)

    %{body: body, status_code: status_code} =
      http.post!(
        "http://0.0.0.0:4001/v1/invoices",
        encode!(%{
          amount: Money.to_decimal(amount),
          currency: currency,
          exchange_rate: rate,
          fiat_currency: fiat_currency,
          required_confirmations: 2,
          finalize: finalize
        }),
        [
          {"content-type", "application/json"},
          {"Authorization", Plug.BasicAuth.encode_basic_auth("user", "")}
        ]
      )

    if status_code == 200 do
      decode_invoice(body)
    else
      {:error, error_changeset(body)}
    end
  end

  # Events

  def subscribe(invoice_id) do
    PubSub.subscribe(@pubsub, topic(invoice_id))
    GenServer.call(__MODULE__, {:join, invoice_id})
  end

  def unsubscribe(invoice_id) do
    PubSub.unsubscribe(@pubsub, topic(invoice_id))
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:join, invoice_id}, _from, state) do
    {:ok, _channel} = Channels.join(topic(invoice_id))
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(msg = %Message{event: "processing"}, state) do
    process_info(:processing, msg, [:id, :status, :reason, :txs])
    {:noreply, state}
  end

  @impl true
  def handle_info(msg = %Message{event: "uncollectible"}, state) do
    process_info(:uncollectible, msg, [:id, :status, :reason])
    {:noreply, state}
  end

  @impl true
  def handle_info(msg = %Message{event: "underpaid"}, state) do
    process_info(:underpaid, msg, [:id, :status, :amount_due, :txs])
    {:noreply, state}
  end

  @impl true
  def handle_info(msg = %Message{event: "overpaid"}, state) do
    process_info(:overpaid, msg, [:id, :status, :overpaid_amount, :txs])
    {:noreply, state}
  end

  @impl true
  def handle_info(msg = %Message{event: "paid"}, state) do
    process_info(:paid, msg, [:id, :status])
    {:noreply, state}
  end

  # voided
  # deleted
  # finalized

  @impl true
  def handle_info(%Message{event: event, payload: params}, state) do
    Logger.warn("unknown event: #{event} #{inspect(params)}")
    {:noreply, state}
  end

  defp process_info(event, %Message{payload: params, topic: topic}, required) do
    case cast_general(params, required) do
      {:ok, data} ->
        PubSub.broadcast(@pubsub, topic, {:invoice, event, data})

      {:error, changeset} ->
        Logger.error("couldn't parse info payload: #{inspect(changeset)}")
    end
  end

  defp topic(invoice_id) do
    "invoice:#{invoice_id}"
  end

  defp encode!(x) when is_map(x) and not is_struct(x) do
    Poison.encode!(
      x
      |> Enum.map(fn {key, val} -> {key, encode!(val)} end)
      |> Enum.into(%{})
    )
  end

  defp encode!(x = %Decimal{}) do
    x
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
  end

  defp encode!(x), do: x

  defp decode_invoice(body) do
    with {:ok, params} <- Poison.decode(body),
         {:ok, invoice} <- Invoice.cast(params) do
      {:ok, invoice}
    else
      {:error, changeset = %Changeset{}} ->
        {:error, changeset}

      error ->
        Logger.warn("couldn't decode response: #{inspect(body)} #{inspect(error)}")
        {:error, %Changeset{}}
    end
  end

  def cast_general(params, required) do
    types = %{
      id: :string,
      reason: :string,
      status: :string,
      amount_due: :decimal,
      overpaid_amount: :decimal,
      confirmations_due: :integer,
      txs: :any
    }

    {%{}, types}
    |> cast(params, Map.keys(types))
    |> Transaction.cast_txs(params)
    |> Invoice.cast_status()
    |> validate_required(required)
    |> apply_action(:cast)
  end

  defp error_changeset(_body) do
    %Changeset{}
  end
end
