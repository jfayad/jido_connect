defmodule Jido.Connect.Google.Sheets.Handlers.Actions.DeleteSheet do
  @moduledoc false

  alias Jido.Connect.Google.Sheets.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <- client.delete_sheet(input, Map.get(credentials, :access_token)) do
      {:ok, %{result: result}}
    end
  end

  defp fetch_client(%{google_sheets_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
