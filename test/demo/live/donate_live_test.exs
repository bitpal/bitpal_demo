defmodule Demo.DonateLiveTest do
  use Demo.ConnCase
  import Phoenix.LiveViewTest
  import Mox
  import Swoosh.TestAssertions
  alias BitPalPhx.ExchangeRates
  alias BitPalPhx.Invoices
  alias PhoenixClient.Message

  @http_client BitPalPhx.HTTPMock

  setup :verify_on_exit!
  setup :set_swoosh_global

  defp broadcast(module, event, payload, topic) do
    pid = GenServer.whereis(module)
    send(pid, %Message{event: event, payload: payload, topic: topic})
  end

  defp eventually(func) do
    if func.() do
      true
    else
      Process.sleep(10)
      eventually(func)
    end
  end

  defp render_eventually(view, match) do
    eventually(fn -> render(view) =~ match end)
  end

  test "successful 0-conf payment", %{conn: conn} do
    {:ok, view, setup} = live(conn, "/")

    assert setup =~ "Amount (BCH)"

    id = "my-id"
    rate = "2"
    amount = "1.3"
    address = "some-address"
    invoice_topic = "invoice:#{id}"

    broadcast(ExchangeRates, "rate", %{"rate" => rate, "pair" => "BCH-USD"}, "not-used")

    assert render_eventually(view, "1 BCH = #{rate} USD")

    expect(@http_client, :post!, fn _url, _params, _headers ->
      %{
        body:
          Poison.encode!(%{
            "id" => id,
            "address" => address,
            "amount" => amount,
            "currency" => "BCH",
            "fiat_amount" => "2.6",
            "fiat_currency" => "USD",
            "status" => "open"
          }),
        status_code: 200
      }
    end)

    wait_for_tx =
      view
      |> element(".setup form")
      |> render_submit(%{"setup" => %{"amount" => amount, "email" => "test@bitpal.dev"}})

    wait_for_tx =~ address

    broadcast(
      Invoices,
      "processing",
      %{
        "id" => id,
        "status" => "processing",
        "reason" => "verifying",
        "txs" => [%{"txid" => "tx0", "amount" => amount}]
      },
      invoice_topic
    )

    assert render_eventually(view, "Verifying 0-conf security")

    broadcast(
      Invoices,
      "paid",
      %{
        "id" => id,
        "status" => "paid"
      },
      invoice_topic
    )

    assert render_eventually(view, "Your payment of <b>#{amount} BCH</b> has been completed!")

    assert_email_sent()
  end

  @tag do: true
  test "successful 2-conf payment", %{conn: conn} do
    {:ok, view, setup} = live(conn, "/")

    assert setup =~ "Amount (BCH)"

    id = "my-id"
    rate = "2"
    amount = "1.3"
    address = "some-address"
    invoice_topic = "invoice:#{id}"

    broadcast(ExchangeRates, "rate", %{"rate" => rate, "pair" => "BCH-USD"}, "not-used")

    assert render_eventually(view, "1 BCH = #{rate} USD")

    expect(@http_client, :post!, fn _url, _params, _headers ->
      %{
        body:
          Poison.encode!(%{
            "id" => id,
            "address" => address,
            "amount" => amount,
            "currency" => "BCH",
            "fiat_amount" => "2.6",
            "fiat_currency" => "USD",
            "status" => "open"
          }),
        status_code: 200
      }
    end)

    wait_for_tx =
      view
      |> element(".setup form")
      |> render_submit(%{"setup" => %{"amount" => amount, "email" => "test@bitpal.dev"}})

    wait_for_tx =~ address

    broadcast(
      Invoices,
      "processing",
      %{
        "id" => id,
        "status" => "processing",
        "reason" => "confirming",
        "confirmations_due" => "2",
        "txs" => [%{"txid" => "tx0", "amount" => amount}]
      },
      invoice_topic
    )

    assert render_eventually(view, "Waiting for <b>2</b> additional confirmations")

    broadcast(
      Invoices,
      "processing",
      %{
        "id" => id,
        "status" => "processing",
        "reason" => "confirming",
        "confirmations_due" => "1",
        "txs" => [%{"txid" => "tx0", "amount" => amount}]
      },
      invoice_topic
    )

    assert render_eventually(view, "Waiting for <b>1</b> additional confirmations")

    broadcast(
      Invoices,
      "paid",
      %{
        "id" => id,
        "status" => "paid"
      },
      invoice_topic
    )

    assert render_eventually(view, "Your payment of <b>#{amount} BCH</b> has been completed!")

    assert_email_sent()
  end
end
