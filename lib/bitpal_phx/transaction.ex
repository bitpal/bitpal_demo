defmodule BitPalPhx.Transaction do
  @moduledoc false
  import Ecto.Changeset
  alias BitPalPhx.Transaction
  alias Ecto.Changeset

  @type t :: %Transaction{
          txid: String.t(),
          amount: Money.t(),
          confirmed_height: non_neg_integer,
          double_spent: boolean
        }

  defstruct [:txid, :amount, :confirmed_height, :double_spent]

  @spec cast_txs(Changeset.t(), map) :: Changeset.t()
  def cast_txs(changeset, params) do
    txs = params["txs"]

    if txs do
      case cast_txs(txs) do
        {:ok, txs} ->
          force_change(changeset, :txs, txs)

        :error ->
          add_error(changeset, :txs, "is invalid")
      end
    else
      changeset
    end
  end

  @spec cast_txs(list) :: {:ok, t} | :error
  def cast_txs(txs) when is_list(txs) do
    Enum.reduce(txs, {:ok, []}, fn
      tx, {:ok, txs} ->
        case cast(tx) do
          {:ok, tx} -> {:ok, [tx | txs]}
          {:error, _} -> :error
        end

      _, :error ->
        :error
    end)
    |> then(fn
      {:ok, txs} -> {:ok, Enum.reverse(txs)}
      :error -> :error
    end)
  end

  @spec cast(map) :: {:ok, t} | {:error, Changeset.t()}
  def cast(params) when is_map(params) do
    types = %{
      txid: :string,
      amount: :decimal,
      confirmed_height: :integer,
      double_spent: :boolean
    }

    {%Transaction{}, types}
    |> cast(params, Map.keys(types))
    |> validate_required([:txid, :amount])
    |> apply_action(:cast)
  end
end
