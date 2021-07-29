defmodule BitPalPhx.Invoice do
  @moduledoc false
  import Ecto.Changeset
  alias BitPalPhx.ExchangeRate
  alias BitPalPhx.Invoice
  alias BitPalPhx.Transaction

  @type status :: :draft | :open | :processing | :uncollectible | :void | :paid
  @type t :: %__MODULE__{
          id: String.t(),
          amount: Money.t() | nil,
          fiat_amount: Money.t() | nil,
          exchange_rate: ExchangeRate.t() | nil,
          address: String.t() | nil,
          status: status,
          reason: String.t() | nil,
          confirmations_due: non_neg_integer | nil,
          email: String.t() | nil,
          description: String.t() | nil,
          pos_data: map | nil,
          txs: [Transaction.t()]
        }

  defstruct [
    :id,
    :amount,
    :fiat_amount,
    :exchange_rate,
    :address,
    :status,
    :reason,
    :confirmations_due,
    :email,
    :description,
    :pos_data,
    :txs
  ]

  @spec merge!(t, map) :: t
  def merge!(invoice = %__MODULE__{}, params) do
    if invoice.id != params.id do
      raise RuntimeError, "mismatched id #{invoice.id} #{params.id}"
    end

    params =
      params
      |> decimal_to_money(invoice, :amount)
      |> decimal_to_money(invoice, :fiat_amount)

    Map.merge(invoice, params)
  end

  defp decimal_to_money(params, invoice, key) do
    case Map.fetch(params, key) do
      {:ok, dec} ->
        currency = Map.fetch!(invoice, key).currency
        new = Money.parse!(dec, currency)
        Map.put(params, key, new)

      :error ->
        params
    end
  end

  def cast(params) when is_map(params) do
    types = %{
      id: :string,
      address: :string,
      status: :string,
      amount: :string,
      fiat_amount: :string,
      exchange_rate: :any,
      email: :string,
      description: :string,
      pos_data: %{},
      txs: :any
    }

    {%BitPalPhx.Invoice{}, types}
    |> cast(params, Map.keys(types))
    |> validate_required([:id, :address, :status, :amount])
    |> cast_money(params, :amount, :currency)
    |> cast_money(params, :fiat_amount, :fiat_currency)
    |> calculate_exchange_rate()
    |> cast_status()
    |> Transaction.cast_txs(params)
    |> apply_action(:cast)
  end

  defp cast_money(changeset, params, amount_key, currency_key) do
    amount = params[Atom.to_string(amount_key)]
    currency = params[Atom.to_string(currency_key)]

    cond do
      !currency ->
        add_error(changeset, currency_key, "cannot be empty")

      !amount ->
        add_error(changeset, currency_key, "cannot be empty")

      true ->
        case Money.parse(Decimal.new(amount), currency) do
          {:ok, money} ->
            force_change(changeset, amount_key, money)

          :error ->
            add_error(changeset, amount_key, "failed to parse money")
        end
    end
  end

  def cast_status(changeset) do
    changeset
    |> validate_inclusion(:status, [
      "draft",
      "open",
      "processing",
      "uncollectible",
      "void",
      "paid"
    ])
    |> cast_atom(:status)
  end

  defp cast_atom(changeset, key) do
    update_change(changeset, key, fn val ->
      String.to_existing_atom(val)
    end)
  end

  def calculate_exchange_rate(invoice = %Invoice{amount: amount, fiat_amount: fiat_amount}) do
    case ExchangeRate.new(amount, fiat_amount) do
      {:ok, rate} -> %{invoice | exchange_rate: rate}
      :error -> invoice
    end
  end

  def calculate_exchange_rate(invoice = %Invoice{}) do
    invoice
  end

  def calculate_exchange_rate(changeset = %Ecto.Changeset{}) do
    amount = get_change(changeset, :amount)
    fiat_amount = get_change(changeset, :fiat_amount)

    if amount && fiat_amount do
      put_change(changeset, :exchange_rate, ExchangeRate.new(amount, fiat_amount))
    else
      changeset
    end
  end
end
