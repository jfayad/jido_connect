defmodule Jido.Connect.Google.Sheets.Handlers.Actions.GetSpreadsheet do
  @moduledoc false

  alias Jido.Connect.Google.Sheets.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, spreadsheet} <-
           client.get_spreadsheet(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{spreadsheet: public_map(spreadsheet)}}
    end
  end

  defp normalize_input(input) do
    input
    |> Map.put_new(:ranges, [])
    |> Map.put_new(:include_grid_data, false)
  end

  defp fetch_client(%{google_sheets_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()

  defp public_map(map) when is_map(map) do
    Map.update(map, :sheets, [], fn sheets -> Enum.map(sheets, &public_map/1) end)
  end

  defp public_map(value), do: value
end
