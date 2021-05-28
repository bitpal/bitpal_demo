defmodule Demo.PaymentLive do
  @moduledoc """
  Logic for acceptong a payment using the BitPal library, using Phoenix LiveView.
  """

  use Demo, :live_view
  alias BitPal
  alias BitPal.AddressEvents
  alias BitPal.ExchangeRate
  alias BitPalSchemas.Transaction
  require Logger
  import Ecto.Changeset

  @required_confirmations 0
  @pair {:BCH, :USD}

  @impl true
  def mount(_params, _session, socket) do
    ExchangeRate.subscribe(@pair)

    {:ok,
     assign(socket,
       state: :setup,
       exchange_rate: nil,
       form: form_changeset()
     )}
  end

  @impl true
  def render(assigns = %{state: state}) do
    # Dynamically figure out which template to render depending on the current state we're in.
    template = Atom.to_string(state) <> ".html"
    render_existing(Demo.PaymentView, template, assigns)
  end

  @impl true
  def handle_event("submit", %{"setup" => form}, socket) do
    # Leverage Phoenix LiveView for form validation.
    case register_params(form, socket) do
      {:ok, params} ->
        # Initialize an invoice, callbacks goes to 'handle_info'.
        case BitPal.register_and_finalize(params) do
          {:ok, _} ->
            {:noreply, assign(socket, transactions: %{}, email: params[:email])}

          {:error, changeset} ->
            {:noreply, assign(socket, form: changeset)}
        end

      {:error, changeset} ->
        {:noreply, assign(socket, form: changeset)}
    end
  end

  # Use LiveView for interactive form validation and fiat update.
  @impl true
  def handle_event("change", %{"setup" => form}, socket) do
    changeset = %{form_changeset(form) | action: :change}

    {:noreply, assign(socket, amount: Map.get(changeset.changes, :amount), form: changeset)}
  end

  @impl true
  def handle_info({:invoice_status, :paid, invoice}, socket) do
    if email = Map.get(socket.assigns, :email) do
      Demo.Mailer.thank_you_email(email, invoice)
    end

    {:noreply, assign(socket, state: :paid)}
  end

  @impl true
  def handle_info({:invoice_status, status, invoice}, socket) do
    if status == :open do
      # We want to track tx confirmations and stuff too
      AddressEvents.subscribe(invoice.address_id)
    end

    socket =
      socket
      |> assign(invoice: invoice)
      |> assign(state: status)

    {:noreply, socket}
  end

  @impl true
  def handle_info({_, tx = %Transaction{}}, socket) do
    {:noreply,
     update(socket, :transactions, fn txs ->
       Map.put(txs, tx.id, tx)
     end)}
  end

  @impl true
  def handle_info({:exchange_rate, rate}, socket) do
    # We only update our exchange rate once, so it doesn't change during a connection.
    ExchangeRate.unsubscribe(rate.pair)

    {:noreply, assign(socket, exchange_rate: rate)}
  end

  defp form_changeset(params \\ %{}) do
    form = %{email: :string, amount: :float}

    {%{}, form}
    |> cast(params, Map.keys(form))
    |> is_invalid_error_message(:amount, "Amount must be a number like '1.3'")
    |> validate_format(:email, ~r/^.+@.+$/, message: "Must be a valid email")
    |> validate_required(:amount, message: "Must specify an amount")
    |> validate_number(:amount,
      greater_than_or_equal_to: 0.00001,
      message: "Must be at least 1000 satoshi (0.00001)"
    )
  end

  defp register_params(form, socket) do
    case form_changeset(form) |> apply_action(:setup) do
      {:ok, params} ->
        params =
          params
          |> Map.update!(:amount, &Money.parse!(&1, :BCH))
          |> Map.merge(%{
            # If we haven't received an exchange rate, block until we have one.
            exchange_rate:
              Map.get(socket.assigns, :exchange_rate) || ExchangeRate.request!(@pair),
            required_confirmations: @required_confirmations,
            description: "Donation to BitPal"
          })

        {:ok, params}

      err ->
        err
    end
  end

  # This is a workaround for cast not supporting a custom error message.
  defp is_invalid_error_message(changeset, key, new_error_message) do
    update_in(
      changeset.errors,
      &Enum.map(&1, fn
        {^key, {"is invalid", reason}} -> {key, {new_error_message, reason}}
        x -> x
      end)
    )
  end
end
