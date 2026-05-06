defmodule Jido.Connect.Google.Contacts.Handlers.Actions.SearchPeople do
  @moduledoc false

  alias Jido.Connect.Google.Contacts.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.search_people(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{people: Enum.map(Map.get(result, :people, []), &public_map/1)}}
    end
  end

  defp normalize_input(input) do
    Map.put_new(input, :page_size, 10)
  end

  defp fetch_client(%{google_contacts_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
