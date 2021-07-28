defmodule BitPalPhx.Cache do
  @moduledoc false

  def start_link(_opts) do
    ConCache.start_link(
      name: __MODULE__,
      ttl_check_interval: :timer.minutes(1),
      global_ttl: :timer.hours(1)
    )
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent
    }
  end

  @spec put(term, term) :: :ok
  def put(key, val) do
    ConCache.put(__MODULE__, key, val)
  end

  @spec get(term) :: term | nil
  def get(key) do
    ConCache.get(__MODULE__, key)
  end

  @spec fetch!(term) :: term
  def fetch!(key) do
    {:ok, res} = fetch(key)
    res
  end

  @spec fetch(term) :: {:ok, term} | :error
  def fetch(key) do
    if val = get(key) do
      {:ok, val}
    else
      :error
    end
  end

  @spec delete(term) :: :ok
  def delete(key) do
    ConCache.delete(__MODULE__, key)
  end
end
