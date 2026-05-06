defmodule Jido.Connect.Gmail.Handlers.Actions.ListMessages do
  @moduledoc false

  alias Jido.Connect.Gmail.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.list_messages(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok,
       %{
         messages: Enum.map(Map.get(result, :messages, []), &public_map/1),
         next_page_token: Map.get(result, :next_page_token),
         result_size_estimate: Map.get(result, :result_size_estimate)
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    end
  end

  defp normalize_input(input) do
    input
    |> Map.put_new(:label_ids, [])
    |> Map.put_new(:page_size, 25)
    |> Map.put_new(:include_spam_trash, false)
  end

  defp fetch_client(%{gmail_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
