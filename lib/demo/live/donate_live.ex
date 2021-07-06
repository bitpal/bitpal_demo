defmodule Demo.DonateLive do
  @moduledoc """
  Handles user specified donation amounts
  """

  use Demo, :live_view
  alias BitPalPhx.Cache
  alias BitPalPhx.ExchangeRates
  alias BitPalPhx.Invoice
  alias BitPalPhx.Invoices
  require Logger
  import Ecto.Changeset

  @pair {"BCH", "USD"}

  @impl true
  def mount(%{"id" => invoice_id}, _session, socket) do
    Logger.info("setting up invoice #{invoice_id}")

    {:ok,
     assign(socket,
       state: :setup,
       exchange_rate: nil,
       form: form_changeset()
     )}
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      ExchangeRates.subscribe(@pair)
    end

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
    render_existing(Demo.DonateView, template, assigns)
  end

  @impl true
  def handle_event("submit", %{"setup" => form}, socket) do
    # Leverage Phoenix LiveView for form validation.
    case register_params(form, socket) do
      {:ok, params} ->
        case Invoices.create(params, finalize: true) do
          {:ok, invoice} ->
            # Store the invoice in the cache, and then retrieve it after patch when params are setup.
            Cache.put(invoice.id, invoice)
            Cache.put({:email, invoice.id}, params[:email])

            socket =
              socket
              |> push_patch(
                to: Routes.donate_path(socket, :invoice, invoice.id),
                replace: true
              )

            {:noreply, socket}

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
  def handle_params(%{"id" => invoice_id}, _uri, socket) do
    socket = assign(socket, email: Cache.get({:email, invoice_id}))

    case retrieve_invoice(invoice_id) do
      {:ok, invoice} ->
        Invoices.subscribe(invoice_id)
        {:noreply, assign(socket, invoice: invoice, state: invoice.status)}

      {:error, _} ->
        Logger.warn("unknown invoice: #{invoice_id}")

        socket =
          socket
          |> push_patch(
            to: Routes.donate_path(socket, :setup),
            replace: true
          )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_params(_, _uri, socket) do
    {:noreply, socket}
  end

  defp retrieve_invoice(invoice_id) do
    if invoice = Cache.get(invoice_id) do
      # Delete the temporary cache as it might get out of sync. It's just a workaround for
      # push_path removing socket assign.
      Cache.delete(invoice_id)
      {:ok, invoice}
    else
      Invoices.fetch(invoice_id)
    end
  end

  @impl true
  def handle_info({:exchange_rate, rate}, socket) do
    # We only update our exchange rate once, so it doesn't change during a connection.
    ExchangeRates.unsubscribe(rate.pair)
    {:noreply, assign(socket, exchange_rate: rate)}
  end

  @impl true
  def handle_info({:invoice, event, params}, socket) do
    Logger.debug("#{event}: #{inspect(params)}")

    case socket.assigns[:invoice] do
      invoice = %Invoice{} ->
        invoice = Invoice.merge!(invoice, params)

        if event == :paid do
          Demo.Mailer.thank_you_email(socket.assigns[:email], invoice)
        end

        {:noreply, assign(socket, invoice: invoice, state: invoice.status)}

      nil ->
        {:noreply, socket}
    end
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
          |> Map.put(
            :exchange_rate,
            # If we haven't received an exchange rate, block until we have one.
            socket.assigns[:exchange_rate] || ExchangeRates.request!(@pair)
          )

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
