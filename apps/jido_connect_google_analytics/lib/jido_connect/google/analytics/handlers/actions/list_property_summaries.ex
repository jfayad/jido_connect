defmodule Jido.Connect.Google.Analytics.Handlers.Actions.ListPropertySummaries do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Analytics.Handlers.Actions.ResourceHelpers

  @max_page_size 200

  def run(input, %{credentials: credentials}) do
    with {:ok, params} <- list_input(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <-
           client.list_property_summaries(params, Map.get(credentials, :access_token)) do
      {:ok,
       %{
         property_summaries:
           result
           |> Map.get(:property_summaries, [])
           |> Enum.map(&ResourceHelpers.public_map/1),
         next_page_token: Map.get(result, :next_page_token)
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    end
  end

  defp list_input(input) do
    with {:ok, page_size} <- page_size(input),
         {:ok, page_token} <- page_token(input) do
      {:ok,
       %{}
       |> put_present(:page_size, page_size)
       |> put_present(:page_token, page_token)}
    end
  end

  defp page_size(input) do
    case Data.get(input, :page_size, 50) do
      nil ->
        {:ok, nil}

      value when is_integer(value) and value > 0 and value <= @max_page_size ->
        {:ok, value}

      value ->
        {:error,
         Error.validation("Google Analytics property summary page_size is invalid",
           reason: :invalid_property_summary_request,
           details: %{field: :page_size, value: value, min: 1, max: @max_page_size}
         )}
    end
  end

  defp page_token(input) do
    case Data.get(input, :page_token) do
      value when is_binary(value) ->
        {:ok, String.trim(value)}

      _other ->
        {:ok, nil}
    end
  end

  defp put_present(map, _key, nil), do: map
  defp put_present(map, _key, ""), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)
end
