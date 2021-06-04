defmodule Demo.PaymentLiveTest do
  use Demo.ConnCase
  alias BitPal.BackendMock
  alias BitPal.ExchangeRate
  alias BitPal.InvoiceManager

  import Phoenix.LiveViewTest

  setup do
    InvoiceManager.terminate_children()
  end

  defp eventually(func) do
    if func.() do
      true
    else
      Process.sleep(10)
      eventually(func)
    end
  end

  test "successful 0-conf payment", %{conn: conn} do
    BitPal.configure(double_spend_timeout: 1)
    BitPal.configure(required_confirmations: 0)

    {:ok, view, setup} = live(conn, "/")

    assert setup =~ "Amount (BCH)"

    wait_for_tx =
      view
      |> element(".setup form")
      |> render_submit(%{"setup" => %{"amount" => 1.3, "email" => ""}})

    rate = Decimal.to_string(ExchangeRate.request!({:BCH, :USD}).rate)

    assert Regex.match?(~r/\d+\.\d+/, rate)
    assert wait_for_tx =~ "1 BCH = #{rate} USD"

    invoice =
      InvoiceManager.tracked_invoices()
      |> List.first()

    assert invoice != nil

    BackendMock.tx_seen(invoice)

    assert eventually(fn ->
             render(view) =~ "Your payment of <b>1.3 BCH</b> has been completed!"
           end)
  end

  @tag do: true
  test "waiting for 0-conf payment", %{conn: conn} do
    BitPal.configure(double_spend_timeout: 1_000)
    BitPal.configure(required_confirmations: 0)

    {:ok, view, _setup} = live(conn, "/")

    view
    |> element(".setup form")
    |> render_submit(%{"setup" => %{"amount" => 3.4, "email" => ""}})

    invoice =
      InvoiceManager.tracked_invoices()
      |> List.first()

    assert invoice != nil

    BackendMock.tx_seen(invoice)

    assert eventually(fn ->
             render(view) =~ "Verifying 0-conf security"
           end)
  end

  test "successful 3-conf payment", %{conn: conn} do
    BitPal.configure(double_spend_timeout: 1)
    BitPal.configure(required_confirmations: 3)

    {:ok, view, setup} = live(conn, "/")

    assert setup =~ "Amount (BCH)"

    view
    |> element(".setup form")
    |> render_submit(%{"setup" => %{"amount" => 4, "email" => ""}})

    invoice =
      InvoiceManager.tracked_invoices()
      |> List.first()

    assert invoice != nil

    BackendMock.confirmed_in_new_block(invoice)

    assert eventually(fn ->
             render(view) =~ "Waiting for <b>2</b> additional confirmations..."
           end)

    BackendMock.issue_blocks(2)

    assert eventually(fn ->
             render(view) =~ "Your payment of <b>4 BCH</b> has been completed!"
           end)
  end
end
