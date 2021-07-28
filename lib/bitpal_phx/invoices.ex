defmodule BitPalPhx.Invoices do
  @moduledoc false
  use GenServer
  import Ecto.Changeset
  alias BitPalPhx.Invoice
  alias BitPalPhx.Socket
  alias BitPalPhx.Transaction
  alias Ecto.Changeset
  alias Phoenix.PubSub
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
            email: String.t(),
            finalize: boolean
          },
          keyword
        ) :: {:ok, Invoice.t()} | {:error, Changeset.t()}
  def create(
        %{
          amount: amount,
          exchange_rate: %{rate: rate, pair: {currency, fiat_currency}},
          email: email
        },
        opts \\ []
      ) do
    finalize = Keyword.get(opts, :finalize, false)

    http = Application.get_env(:demo, :http_client)
    token = Application.fetch_env!(:demo, :access_token)
    uri = Application.fetch_env!(:demo, :rest_endpoint)

    %{body: body, status_code: status_code} =
      http.post!(
        "#{uri}/v1/invoices",
        encode!(%{
          amount: Money.to_decimal(amount),
          currency: currency,
          exchange_rate: rate,
          fiat_currency: fiat_currency,
          required_confirmations: Application.get_env(:demo, :required_confirmations, 0),
          email: email,
          finalize: finalize
        }),
        [
          {"content-type", "application/json"},
          {"Authorization", Plug.BasicAuth.encode_basic_auth(token, "")}
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
    :ok = Socket.join(topic(invoice_id))
    {:reply, :ok, state}
  end

  def handle_message(topic, "processing", msg) do
    process_info(:processing, topic, msg, [:id, :status, :reason, :txs])
  end

  def handle_message(topic, "uncollectible", msg) do
    process_info(:uncollectible, topic, msg, [:id, :status, :reason])
  end

  def handle_message(topic, "underpaid", msg) do
    process_info(:underpaid, topic, msg, [:id, :status, :amount_due, :txs])
  end

  def handle_message(topic, "overpaid", msg) do
    process_info(:overpaid, topic, msg, [:id, :status, :overpaid_amount, :txs])
  end

  def handle_message(topic, "paid", msg) do
    process_info(:paid, topic, msg, [:id, :status])
  end

  def handle_message(_topic, event, message) do
    # NOTE we ignore voided, deleted and finalized messages which aren't relevant to this use-case.
    Logger.warn("unknown invoice event: #{event} #{inspect(message)}")
  end

  defp process_info(event, topic, msg, required) do
    case cast_general(msg, required) do
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
