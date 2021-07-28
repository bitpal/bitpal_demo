defmodule Demo.Mailer do
  @moduledoc false
  use Swoosh.Mailer, otp_app: :demo
  alias BitPalPhx.Invoice
  require Logger

  def thank_you_email(%Invoice{email: nil}), do: nil

  def thank_you_email(invoice) do
    Logger.info("Thanking #{invoice.email}!")

    Task.start(fn ->
      %{email: invoice.email, amount: invoice.amount}
      |> Demo.AcceptedEmail.new()
      |> Demo.Mailer.deliver()
    end)
  end
end

defmodule Demo.AcceptedEmail do
  @moduledoc false
  use Phoenix.Swoosh, view: Demo.EmailView, layout: {Demo.LayoutView, :email}

  def new(payee) do
    new()
    |> from("noreply@bitpal.dev")
    |> to(payee.email)
    |> subject("Your payment to BitPal has been accepted!")
    |> render_body("accepted.html", %{amount: payee.amount})
  end
end
