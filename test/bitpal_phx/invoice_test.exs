defmodule BitPalPhx.InvoiceTest do
  use ExUnit.Case, async: true
  alias BitPalPhx.ExchangeRate
  alias BitPalPhx.Invoice
  alias BitPalPhx.Invoices
  alias BitPalPhx.Transaction

  test "casting invoice" do
    assert {:ok,
            %Invoice{
              id: "my_id",
              address: "my_address",
              status: :open,
              amount: Money.parse!("5.0", "BCH"),
              fiat_amount: Money.parse!("4.0", "USD"),
              exchange_rate: %ExchangeRate{rate: Decimal.new("0.8"), pair: {:BCH, :USD}},
              txs: [
                %Transaction{
                  txid: "tx0",
                  amount: Decimal.new("0.3"),
                  confirmed_height: 5
                },
                %Transaction{
                  txid: "tx1",
                  amount: Decimal.new("0.1"),
                  double_spent: true
                }
              ]
            }} ==
             Invoice.cast(%{
               "id" => "my_id",
               "address" => "my_address",
               "status" => "open",
               "amount" => "5.0",
               "fiat_amount" => "4.0",
               "currency" => "BCH",
               "fiat_currency" => "USD",
               "txs" => [
                 %{
                   "txid" => "tx0",
                   "amount" => "0.3",
                   "confirmed_height" => 5
                 },
                 %{
                   "txid" => "tx1",
                   "amount" => "0.1",
                   "double_spent" => true
                 }
               ]
             })
  end

  test "merge invoice" do
    invoice = %Invoice{
      id: "my_id",
      status: :draft,
      amount: Money.parse!("5.0", "BCH"),
      fiat_amount: Money.parse!("4.0", "USD")
    }

    assert %Invoice{
             id: "my_id",
             status: :open,
             amount: Money.parse!("0.01", "BCH"),
             fiat_amount: Money.parse!("1", "USD"),
             txs: [
               %Transaction{
                 txid: "tx0",
                 amount: Decimal.new("0.3"),
                 confirmed_height: 5
               }
             ]
           } ==
             Invoice.merge!(invoice, %{
               id: "my_id",
               status: :open,
               amount: Decimal.new("0.01"),
               fiat_amount: Decimal.new("1"),
               txs: [
                 %Transaction{
                   txid: "tx0",
                   amount: Decimal.new("0.3"),
                   confirmed_height: 5
                 }
               ]
             })
  end

  test "casting general" do
    assert {:ok,
            %{
              id: "my_id",
              reason: "verifying",
              amount_due: Decimal.new("0.4"),
              overpaid_amount: Decimal.new("0.7")
            }} ==
             Invoices.cast_general(
               %{
                 "id" => "my_id",
                 "reason" => "verifying",
                 "amount_due" => "0.4",
                 "overpaid_amount" => "0.7"
               },
               [:id, :reason, :amount_due]
             )
  end

  test "casting general txs" do
    assert {:ok,
            %{
              id: "my_id",
              reason: "verifying",
              amount_due: Decimal.new("0.4"),
              txs: [
                %Transaction{
                  txid: "tx0",
                  amount: Decimal.new("0.3"),
                  confirmed_height: 5
                },
                %Transaction{
                  txid: "tx1",
                  amount: Decimal.new("0.1"),
                  double_spent: true
                }
              ]
            }} ==
             Invoices.cast_general(
               %{
                 "id" => "my_id",
                 "reason" => "verifying",
                 "amount_due" => "0.4",
                 "txs" => [
                   %{
                     "txid" => "tx0",
                     "amount" => "0.3",
                     "confirmed_height" => 5
                   },
                   %{
                     "txid" => "tx1",
                     "amount" => "0.1",
                     "double_spent" => true
                   }
                 ]
               },
               [:id, :reason, :amount_due, :txs]
             )
  end
end
