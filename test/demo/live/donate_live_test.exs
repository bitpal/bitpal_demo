defmodule Demo.DonateLiveTest do
  use Demo.ConnCase
  import Phoenix.LiveViewTest
  import Mox
  import Swoosh.TestAssertions
  alias BitPalPhx.Socket

  @http_client BitPalPhx.HTTPMock
  @socket_client BitPalPhx.SocketMock

  setup :verify_on_exit!
  setup :set_swoosh_global
  setup :set_mox_global

  setup do
    stub(@socket_client, :join, fn _channel -> :ok end)
    :ok
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
    id = "my-id"
    rate = "2"
    amount = "1.3"
    address = "some-address"
    invoice_topic = "invoice:#{id}"

    expect(@socket_client, :push, fn "exchange_rate:BCH-USD", "rate", %{from: "BCH", to: "USD"} ->
      {:ok, "rate-ref"}
    end)

    expect(@socket_client, :await, fn "rate-ref" ->
      {:ok, %{"rate" => rate, "pair" => "BCH-USD"}}
    end)

    {:ok, view, setup} = live(conn, "/")

    assert setup =~ "Amount (BCH)"
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
            "status" => "open",
            "email" => "test@bitpal.dev"
          }),
        status_code: 200
      }
    end)

    wait_for_tx =
      view
      |> element(".setup form")
      |> render_submit(%{"setup" => %{"amount" => amount, "email" => "test@bitpal.dev"}})

    wait_for_tx =~ address

    Socket.handle_message(
      invoice_topic,
      "processing",
      %{
        "id" => id,
        "status" => "processing",
        "reason" => "verifying",
        "txs" => [%{"txid" => "tx0", "amount" => amount}]
      }
    )

    assert render_eventually(view, "Verifying 0-conf security")

    Socket.handle_message(
      invoice_topic,
      "paid",
      %{
        "id" => id,
        "status" => "paid"
      }
    )

    assert render_eventually(view, "Your payment of <b>#{amount} BCH</b> has been completed!")
    assert render(view) =~ "A verification email has been sent to <b>test@bitpal.dev</b>"
    Process.sleep(10)
    assert_email_sent()
  end

  test "successful 2-conf payment", %{conn: conn} do
    id = "my-id"
    rate = "2"
    amount = "1.3"
    address = "some-address"
    invoice_topic = "invoice:#{id}"

    expect(@socket_client, :push, fn "exchange_rate:BCH-USD", "rate", %{from: "BCH", to: "USD"} ->
      {:ok, "rate-ref"}
    end)

    expect(@socket_client, :await, fn "rate-ref" ->
      {:ok, %{"rate" => rate, "pair" => "BCH-USD"}}
    end)

    {:ok, view, setup} = live(conn, "/")

    assert setup =~ "Amount (BCH)"
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

    Socket.handle_message(
      invoice_topic,
      "processing",
      %{
        "id" => id,
        "status" => "processing",
        "reason" => "confirming",
        "confirmations_due" => "2",
        "txs" => [%{"txid" => "tx0", "amount" => amount}]
      }
    )

    assert render_eventually(view, "Waiting for <b>2</b> additional confirmations")

    Socket.handle_message(
      invoice_topic,
      "processing",
      %{
        "id" => id,
        "status" => "processing",
        "reason" => "confirming",
        "confirmations_due" => "1",
        "txs" => [%{"txid" => "tx0", "amount" => amount}]
      }
    )

    assert render_eventually(view, "Waiting for <b>1</b> additional confirmations")

    Socket.handle_message(
      invoice_topic,
      "paid",
      %{
        "id" => id,
        "status" => "paid"
      }
    )

    assert render_eventually(view, "Your payment of <b>#{amount} BCH</b> has been completed!")
    assert !(render(view) =~ "A verification email has been sent")
  end
end
