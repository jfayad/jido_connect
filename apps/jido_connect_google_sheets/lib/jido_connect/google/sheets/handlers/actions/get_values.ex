defmodule Jido.Connect.Google.Sheets.Handlers.Actions.GetValues do
  @moduledoc false

  alias Jido.Connect.Google.Sheets.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, value_range} <- client.get_values(input, Map.get(credentials, :access_token)) do
      {:ok, %{value_range: public_map(value_range)}}
    end
  end

  defp fetch_client(%{google_sheets_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
end
