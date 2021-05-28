defmodule Demo.PageLiveTest do
  use Demo.ConnCase
  alias BitPal.BackendMock
  alias BitPal.ExchangeRate
  alias BitPal.InvoiceManager

  import Phoenix.LiveViewTest

  defp eventually(func) do
    if func.() do
      true
    else
      Process.sleep(10)
      eventually(func)
    end
  end

  test "successful payment", %{conn: conn} do
    BitPal.configure(double_spend_timeout: 1)

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

    Process.sleep(20)

    assert eventually(fn ->
             render(view) =~ "Your payment of <b>1.3 BCH</b> has been completed!"
           end)
  end
end
