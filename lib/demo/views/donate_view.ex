defmodule Demo.DonateView do
  use Demo, :view

  def fiat_amount(assigns) do
    exchange_rate = Map.get(assigns, :exchange_rate)
    amount = Map.get(assigns, :amount)

    if exchange_rate && amount do
      Decimal.mult(exchange_rate.rate, Decimal.from_float(amount)) |> Decimal.normalize()
    else
      nil
    end
  end

  def bch_amount_s(amount) do
    amount
    |> Decimal.to_string(:normal)
  end

  def form_bch_amount_s(assigns) do
    amount = Map.get(assigns, :amount)

    if amount do
      Decimal.from_float(amount) |> Decimal.normalize() |> Decimal.to_string(:normal)
    else
      nil
    end
  end
end
