defmodule BitPalPhx.HTTPClientAPI do
  @moduledoc false

  @callback post!(String.t(), map, list) :: %{body: String.t(), status_code: non_neg_integer}
  @callback get!(String.t(), list) :: %{body: String.t(), status_code: non_neg_integer}
end

defmodule BitPalPhx.HTTPClient do
  @moduledoc false
  @behaviour BitPalPhx.HTTPClientAPI

  @spec post!(String.t(), map, list) :: %{body: String.t(), status_code: non_neg_integer}
  @impl true
  def post!(url, params, headers \\ []) do
    %HTTPoison.Response{status_code: code, body: body} = HTTPoison.post!(url, params, headers)
    %{status_code: code, body: body}
  end

  @spec get!(String.t(), list) :: %{body: String.t(), status_code: non_neg_integer}
  @impl true
  def get!(url, headers \\ []) do
    %HTTPoison.Response{status_code: code, body: body} = HTTPoison.get!(url, headers)
    %{status_code: code, body: body}
  end
end
